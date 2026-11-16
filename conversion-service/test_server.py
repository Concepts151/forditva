"""Tests for server.py. Run: pip install -r requirements-dev.txt && pytest

App Check tokens are signed with a locally generated key that stands in
for Google's public keys. LibreOffice is replaced by a stub, except in the
real-conversion test, which runs only where `soffice` is installed (for
example inside the Docker image).
"""

import io
import os
import secrets
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

PROJECT_NUMBER = "851863893438"
APP_ID = "1:851863893438:android:c740e257fb79717cefb5ef"
TEST_KEY = "test-key-0123456789abcdef0123456789abcdef"
# NOTE: the converter key is made at run time, so no key value is in git.
CONVERTER_KEY = secrets.token_hex(32)

os.environ["FIREBASE_PROJECT_NUMBER"] = PROJECT_NUMBER
os.environ["FIREBASE_APP_IDS"] = APP_ID
os.environ["INTERNAL_TEST_API_KEY"] = TEST_KEY
os.environ["FORDITVA_CONVERTER_KEY"] = CONVERTER_KEY
os.environ["MAX_UPLOAD_MB"] = "1"

import server  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

REAL_RUN_LIBREOFFICE = server.run_libreoffice

GOOGLE_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
OTHER_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)


class FakeJwksClient:
    class _Key:
        key = GOOGLE_KEY.public_key()

    def get_signing_key_from_jwt(self, token):
        return self._Key()


def make_token(key=GOOGLE_KEY, alg="RS256", **overrides):
    now = int(time.time())
    claims = {
        "iss": f"https://firebaseappcheck.googleapis.com/{PROJECT_NUMBER}",
        "aud": [f"projects/{PROJECT_NUMBER}", "projects/forditva-151"],
        "sub": APP_ID,
        "iat": now,
        "exp": now + 3600,
    }
    claims.update(overrides)
    return jwt.encode(claims, key, algorithm=alg, headers={"kid": "k1", "typ": "JWT"})


def fake_libreoffice(source, workdir):
    (workdir / "input.pdf").write_bytes(b"%PDF-1.7\nfake\n")

    class Result:
        returncode = 0
        stderr = ""

    return Result()


@pytest.fixture(autouse=True)
def stubs(monkeypatch):
    monkeypatch.setattr(server, "jwks_client", FakeJwksClient())
    monkeypatch.setattr(server, "run_libreoffice", fake_libreoffice)


@pytest.fixture
def client():
    return TestClient(server.app)


ZIP_FILE = b"PK\x03\x04" + b"x" * 100


def upload(client, name="brief.docx", content=ZIP_FILE, headers=None):
    return client.post(
        "/convert/to-pdf",
        files={"file": (name, content, "application/octet-stream")},
        headers=headers or {},
    )


def app_check(token=None):
    return {"X-Firebase-AppCheck": token or make_token()}


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_valid_token_returns_pdf_bytes(client):
    response = upload(client, headers=app_check())
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content.startswith(b"%PDF-")
    assert 'filename="brief.pdf"' in response.headers["content-disposition"]


@pytest.mark.parametrize(
    "token",
    [
        make_token(iss="https://firebaseappcheck.googleapis.com/999"),
        make_token(aud=["projects/999"]),
        make_token(sub="1:851863893438:android:someoneelse"),
        make_token(exp=int(time.time()) - 3600),
        make_token(key=OTHER_KEY),
        make_token(alg="HS256", key="not-rsa-secret-at-least-32-bytes-long"),
        "not-a-token",
    ],
    ids=["issuer", "audience", "app-id", "expired", "signature", "alg", "garbage"],
)
def test_invalid_tokens_rejected(client, token):
    assert upload(client, headers=app_check(token)).status_code == 401


def test_no_credentials_rejected(client):
    assert upload(client).status_code == 401


def test_test_key_rejected_from_outside(client):
    assert upload(client, headers={"X-API-Key": TEST_KEY}).status_code == 401


def test_test_key_accepted_from_loopback():
    local = TestClient(server.app, client=("127.0.0.1", 50000))
    assert upload(local, headers={"X-API-Key": TEST_KEY}).status_code == 200
    assert upload(local, headers={"X-API-Key": "wrong"}).status_code == 401


def converter_key(value=CONVERTER_KEY):
    return {"X-Forditva-Converter-Key": value}


@pytest.mark.parametrize(
    "host",
    [None, ("203.0.113.7", 443), ("10.0.0.5", 40000), ("127.0.0.1", 50000)],
    ids=["testclient", "public", "docker-network", "loopback"],
)
def test_converter_key_accepted_from_any_host(host):
    remote = TestClient(server.app, client=host) if host else TestClient(server.app)
    response = upload(remote, headers=converter_key())
    assert response.status_code == 200
    assert response.content.startswith(b"%PDF-")


@pytest.mark.parametrize(
    "value",
    [
        secrets.token_hex(32),
        CONVERTER_KEY + "x",
        CONVERTER_KEY[:-1],
        CONVERTER_KEY.upper(),
        "",
        " ",
        TEST_KEY,
        ("é" * 64).encode("utf-8"),
    ],
    ids=["other", "longer", "shorter", "case", "empty", "space", "test-key", "not-ascii"],
)
def test_wrong_converter_key_rejected(value, caplog):
    caplog.set_level("INFO", logger="forditva-converter")
    remote = TestClient(server.app, client=("203.0.113.7", 443))
    response = upload(remote, headers=converter_key(value))
    assert response.status_code == 401
    assert response.json() == {"detail": "Unauthorized"}
    assert CONVERTER_KEY not in response.text
    assert CONVERTER_KEY not in caplog.text


def test_wrong_converter_key_is_logged_without_the_value(caplog):
    caplog.set_level("INFO", logger="forditva-converter")
    wrong = secrets.token_hex(32)
    remote = TestClient(server.app, client=("203.0.113.7", 443))
    assert upload(remote, headers=converter_key(wrong)).status_code == 401
    assert "Rejected converter key" in caplog.text
    assert wrong not in caplog.text
    assert CONVERTER_KEY not in caplog.text


def test_converter_key_not_in_logs_on_success(caplog):
    caplog.set_level("DEBUG")
    remote = TestClient(server.app, client=("203.0.113.7", 443))
    assert upload(remote, headers=converter_key()).status_code == 200
    assert CONVERTER_KEY not in caplog.text


@pytest.mark.parametrize("value", [CONVERTER_KEY, ""], ids=["key", "empty"])
def test_converter_key_off_when_unset(monkeypatch, value):
    monkeypatch.setattr(server, "FORDITVA_CONVERTER_KEY", "", raising=False)
    for host in [("203.0.113.7", 443), ("127.0.0.1", 50000)]:
        remote = TestClient(server.app, client=host)
        assert upload(remote, headers=converter_key(value)).status_code == 401


def test_converter_key_only_in_its_own_header():
    remote = TestClient(server.app, client=("203.0.113.7", 443))
    assert upload(remote, headers={"X-API-Key": CONVERTER_KEY}).status_code == 401
    assert upload(remote, headers={"X-Firebase-AppCheck": CONVERTER_KEY}).status_code == 401


def test_test_key_still_loopback_only_with_converter_key_on():
    outside = TestClient(server.app, client=("203.0.113.7", 443))
    local = TestClient(server.app, client=("127.0.0.1", 50000))
    assert upload(outside, headers={"X-API-Key": TEST_KEY}).status_code == 401
    assert upload(local, headers={"X-API-Key": TEST_KEY}).status_code == 200


def test_app_check_still_decides_when_a_token_is_sent(client):
    # NOTE: the App Check path is unchanged. A request with a token is decided by the token only.
    assert upload(client, headers={**app_check(), **converter_key(secrets.token_hex(32))}).status_code == 200
    assert upload(client, headers={**app_check("not-a-token"), **converter_key()}).status_code == 401


@pytest.mark.parametrize(
    "value",
    ["k" * 31, "k" * 39 + "+", "k" * 40 + " k", "k" * 40 + "/"],
    ids=["short", "plus", "space-inside", "slash"],
)
def test_bad_converter_key_stops_the_start_without_the_value(value):
    env = {
        **os.environ,
        "FORDITVA_CONVERTER_KEY": value,
        "FIREBASE_PROJECT_NUMBER": PROJECT_NUMBER,
        "FIREBASE_APP_IDS": APP_ID,
    }
    result = subprocess.run(
        [sys.executable, "-c", "import server"],
        cwd=Path(__file__).parent,
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
        check=False,
    )
    assert result.returncode != 0
    assert "FORDITVA_CONVERTER_KEY" in result.stderr
    assert value not in result.stderr
    assert value not in result.stdout


@pytest.mark.parametrize("value", ["", "   "], ids=["empty", "spaces"])
def test_empty_converter_key_starts_with_the_key_off(value):
    env = {
        **os.environ,
        "FORDITVA_CONVERTER_KEY": value,
        "FIREBASE_PROJECT_NUMBER": PROJECT_NUMBER,
        "FIREBASE_APP_IDS": APP_ID,
    }
    result = subprocess.run(
        [sys.executable, "-c", "import server; assert server.FORDITVA_CONVERTER_KEY == ''"],
        cwd=Path(__file__).parent,
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
        check=False,
    )
    assert result.returncode == 0, result.stderr


def test_test_key_off_when_unset(monkeypatch):
    monkeypatch.setattr(server, "INTERNAL_TEST_API_KEY", "")
    local = TestClient(server.app, client=("127.0.0.1", 50000))
    assert upload(local, headers={"X-API-Key": ""}).status_code == 401


@pytest.mark.parametrize(
    "name, content, status",
    [
        ("random.docx", b"\x00\x01garbage" * 50, 400),
        ("text.xlsx", b"just some text", 400),
        ("old.doc", b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1" + b"x" * 100, 200),
        ("rich.doc", b"{\\rtf1\\ansi hello}", 200),
        ("zip.doc", ZIP_FILE, 400),
        ("old.xls", b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1" + b"x" * 100, 200),
        ("calc.ods", ZIP_FILE, 200),
    ],
)
def test_content_must_match_format(client, name, content, status):
    assert upload(client, name=name, content=content, headers=app_check()).status_code == status


def test_unsupported_extension(client):
    assert upload(client, name="notes.txt", headers=app_check()).status_code == 400


def test_empty_file(client):
    assert upload(client, content=b"", headers=app_check()).status_code == 400


def test_upload_too_large(client):
    big = ZIP_FILE + b"x" * server.MAX_UPLOAD_SIZE
    assert upload(client, content=big, headers=app_check()).status_code == 413


def test_pdf_too_large(client, monkeypatch):
    monkeypatch.setattr(server, "MAX_PDF_SIZE", 5)
    assert upload(client, headers=app_check()).status_code == 413


def test_busy(client):
    acquired = 0
    while server.conversion_slots.acquire(blocking=False):
        acquired += 1
    try:
        assert upload(client, headers=app_check()).status_code == 503
    finally:
        for _ in range(acquired):
            server.conversion_slots.release()


def test_failed_conversion(client, monkeypatch):
    class Failed:
        returncode = 1
        stderr = "error"

    monkeypatch.setattr(server, "run_libreoffice", lambda s, w: Failed())
    assert upload(client, headers=app_check()).status_code == 422


def minimal_docx() -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as docx:
        docx.writestr(
            "[Content_Types].xml",
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
            "</Types>",
        )
        docx.writestr(
            "_rels/.rels",
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
            "</Relationships>",
        )
        docx.writestr(
            "word/document.xml",
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            "<w:body><w:p><w:r><w:t>Jó napot kívánok! Guten Tag!</w:t></w:r></w:p></w:body>"
            "</w:document>",
        )
    return buffer.getvalue()


@pytest.mark.skipif(shutil.which("soffice") is None, reason="LibreOffice not installed")
def test_real_docx_conversion(client, monkeypatch):
    monkeypatch.setattr(server, "run_libreoffice", REAL_RUN_LIBREOFFICE)
    response = upload(client, name="Brief für Markus.docx", content=minimal_docx(), headers=app_check())
    assert response.status_code == 200
    assert response.content.startswith(b"%PDF-")
    assert 'filename="Brief_f_r_Markus.pdf"' in response.headers["content-disposition"]
