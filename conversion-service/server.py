"""Forditva document-to-PDF conversion server.

Converts Word, Excel and OpenDocument files to PDF with headless
LibreOffice and returns the PDF bytes directly. The Forditva app then sends
the PDF through its normal PDF path (page picker, then Gemini).

Based on Markus's FastAPI draft (13 October 2026). Changes agreed with him
on 14 October 2026:

- The app authenticates with a Firebase App Check token (Play Integrity),
  checked against Google's public keys. No secret is stored in the app and
  no service account is needed on the server.
- An optional test key works only for requests made from inside the
  container itself (127.0.0.1), never through the public address.
- Limits: 15 MB upload, 30 MB converted PDF, 2 parallel conversions,
  90 second timeout.

Nothing is stored: every request gets its own temporary folder, deleted
after the response has been sent.
"""

import logging
import os
import re
import secrets
import subprocess
import tempfile
import threading
import time
from pathlib import Path

import jwt
from fastapi import FastAPI, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask
from starlette.datastructures import UploadFile

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("forditva-converter")

MB = 1024 * 1024


def _env_int(name: str, default: int) -> int:
    return int(os.environ.get(name, default))


def _required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} environment variable is missing")
    return value


# Firebase project forditva-151. Both values are public, not secrets.
FIREBASE_PROJECT_NUMBER = _required_env("FIREBASE_PROJECT_NUMBER")
FIREBASE_APP_IDS = {
    app_id.strip()
    for app_id in _required_env("FIREBASE_APP_IDS").split(",")
    if app_id.strip()
}
APP_CHECK_ISSUER = f"https://firebaseappcheck.googleapis.com/{FIREBASE_PROJECT_NUMBER}"
APP_CHECK_AUDIENCE = f"projects/{FIREBASE_PROJECT_NUMBER}"
APP_CHECK_JWKS_URL = "https://firebaseappcheck.googleapis.com/v1/jwks"

# Optional. Unset means the test key is switched off.
INTERNAL_TEST_API_KEY = os.environ.get("INTERNAL_TEST_API_KEY", "")
LOOPBACK_HOSTS = {"127.0.0.1", "::1"}

MAX_UPLOAD_SIZE = _env_int("MAX_UPLOAD_MB", 15) * MB
MAX_PDF_SIZE = _env_int("MAX_PDF_MB", 30) * MB
MAX_CONCURRENT_CONVERSIONS = _env_int("MAX_CONCURRENT", 2)
CONVERSION_TIMEOUT = _env_int("TIMEOUT_SECONDS", 90)

# Room for the multipart headers around the file.
MAX_REQUEST_SIZE = MAX_UPLOAD_SIZE + MB

# Allowed formats and how their files must start. LibreOffice reads any
# unrecognised file as plain text and still produces a (garbage) PDF, so
# the extension alone is not enough.
ZIP_MAGIC = b"PK\x03\x04"  # .docx, .xlsx, .odt, .ods
OLE2_MAGIC = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"  # old .doc, .xls
RTF_MAGIC = b"{\\rtf"  # Word also saves RTF under .doc
FILE_SIGNATURES = {
    ".docx": (ZIP_MAGIC,),
    ".xlsx": (ZIP_MAGIC,),
    ".odt": (ZIP_MAGIC,),
    ".ods": (ZIP_MAGIC,),
    ".doc": (OLE2_MAGIC, RTF_MAGIC),
    ".xls": (OLE2_MAGIC,),
}
ALLOWED_EXTENSIONS = set(FILE_SIGNATURES)

# Google's public keys, cached; refetched when a token names an unknown key.
jwks_client = jwt.PyJWKClient(APP_CHECK_JWKS_URL, cache_keys=True, lifespan=6 * 3600)

conversion_slots = threading.BoundedSemaphore(MAX_CONCURRENT_CONVERSIONS)

app = FastAPI(title="Forditva PDF Conversion Server", docs_url=None, redoc_url=None)


def verify_app_check_token(token: str) -> None:
    """Raises HTTPException(401) unless [token] is a valid App Check token
    for one of our apps. Checks signature (RS256, Google's public keys),
    expiry, issuer, audience and app ID."""
    try:
        header = jwt.get_unverified_header(token)
        if header.get("alg") != "RS256" or header.get("typ") != "JWT":
            raise jwt.InvalidTokenError("unexpected token header")
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=APP_CHECK_AUDIENCE,
            issuer=APP_CHECK_ISSUER,
            options={"require": ["exp", "iat", "iss", "aud", "sub"]},
            leeway=30,
        )
    except jwt.PyJWKClientConnectionError:
        log.exception("Could not fetch App Check public keys")
        raise HTTPException(status_code=503, detail="Authentication unavailable; retry shortly")
    except jwt.PyJWTError as error:
        log.info("Rejected App Check token: %s", type(error).__name__)
        raise HTTPException(status_code=401, detail="Unauthorized")

    if claims.get("sub") not in FIREBASE_APP_IDS:
        log.info("Rejected App Check token: unknown app ID")
        raise HTTPException(status_code=401, detail="Unauthorized")


def authenticate(request: Request) -> None:
    app_check_token = request.headers.get("x-firebase-appcheck", "")
    if app_check_token:
        verify_app_check_token(app_check_token)
        return

    # Internal test key: only from inside the container. Requests through
    # the reverse proxy arrive from the Docker network, never from
    # 127.0.0.1, and uvicorn runs without --proxy-headers, so a forwarded
    # header cannot change request.client.
    api_key = request.headers.get("x-api-key", "")
    client_host = request.client.host if request.client else ""
    if (
        api_key
        and INTERNAL_TEST_API_KEY
        and client_host in LOOPBACK_HOSTS
        and secrets.compare_digest(api_key, INTERNAL_TEST_API_KEY)
    ):
        return

    raise HTTPException(status_code=401, detail="Unauthorized")


def run_libreoffice(source: Path, workdir: Path) -> subprocess.CompletedProcess:
    # Isolated LibreOffice profile prevents conflicts between conversions.
    profile = workdir / "lo-profile"
    command = [
        "soffice",
        f"-env:UserInstallation={profile.as_uri()}",
        "--headless",
        "--norestore",
        "--convert-to", "pdf",
        "--outdir", str(workdir),
        str(source),
    ]
    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        timeout=CONVERSION_TIMEOUT,
        check=False,
    )


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/convert/to-pdf")
async def convert_to_pdf(request: Request):
    started = time.monotonic()

    # Authenticate before reading the upload.
    authenticate(request)

    content_length = request.headers.get("content-length")
    if content_length and content_length.isdigit() and int(content_length) > MAX_REQUEST_SIZE:
        raise HTTPException(status_code=413, detail="File is too large")

    if not conversion_slots.acquire(blocking=False):
        raise HTTPException(status_code=503, detail="Conversion service is busy; retry shortly")

    temp = None
    form = None
    response_created = False

    try:
        form = await request.form(max_files=1, max_fields=1)
        upload = form.get("file")
        if not isinstance(upload, UploadFile):
            raise HTTPException(status_code=400, detail="No file uploaded (form field 'file')")

        original_name = upload.filename or ""
        extension = Path(original_name).suffix.lower()
        if extension not in ALLOWED_EXTENSIONS:
            raise HTTPException(status_code=400, detail="Unsupported file format")

        temp = tempfile.TemporaryDirectory(prefix="forditva_conversion_")
        workdir = Path(temp.name)
        # The uploaded name is never used as a path.
        source = workdir / f"input{extension}"
        target = workdir / "input.pdf"

        # Copy in chunks; reject files over the size limit.
        total_bytes = 0
        with source.open("wb") as output:
            while chunk := await upload.read(MB):
                total_bytes += len(chunk)
                if total_bytes > MAX_UPLOAD_SIZE:
                    raise HTTPException(status_code=413, detail="File is too large")
                output.write(chunk)

        if total_bytes == 0:
            raise HTTPException(status_code=400, detail="Uploaded file is empty")

        with source.open("rb") as written:
            head = written.read(8)
        if not head.startswith(FILE_SIGNATURES[extension]):
            raise HTTPException(status_code=400, detail="File content does not match its format")

        try:
            result = await run_in_threadpool(run_libreoffice, source, workdir)
        except subprocess.TimeoutExpired:
            raise HTTPException(status_code=504, detail="Document conversion timed out")
        except FileNotFoundError:
            log.exception("LibreOffice (soffice) is not installed")
            raise HTTPException(status_code=500, detail="LibreOffice is not installed on this server")

        if result.returncode != 0 or not target.is_file():
            log.error(
                "LibreOffice conversion failed: code=%s stderr=%s",
                result.returncode,
                result.stderr[-2000:],
            )
            raise HTTPException(status_code=422, detail="PDF conversion failed")

        with target.open("rb") as pdf:
            if pdf.read(5) != b"%PDF-":
                raise HTTPException(status_code=422, detail="Invalid PDF output")

        pdf_size = target.stat().st_size
        if pdf_size > MAX_PDF_SIZE:
            raise HTTPException(status_code=413, detail="Converted PDF is too large")

        # Safe ASCII filename for Content-Disposition.
        filename_stem = re.sub(r"[^A-Za-z0-9._-]", "_", Path(original_name).stem)[:80] or "document"

        log.info(
            "Converted %s: %d bytes in, %d bytes out, %.1f s",
            extension,
            total_bytes,
            pdf_size,
            time.monotonic() - started,
        )

        response = FileResponse(
            path=str(target),
            media_type="application/pdf",
            filename=f"{filename_stem}.pdf",
            background=BackgroundTask(temp.cleanup),
        )
        response_created = True
        return response

    finally:
        conversion_slots.release()
        if form is not None:
            await form.close()
        # A successful response cleans up after the file has been sent.
        if temp is not None and not response_created:
            temp.cleanup()
