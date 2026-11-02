# Forditva document-to-PDF conversion server

Converts Word, Excel and OpenDocument files (`.doc`, `.docx`, `.xls`,
`.xlsx`, `.odt`, `.ods`) to PDF with headless LibreOffice and returns the
PDF file directly. The Forditva app then handles the PDF like any other
PDF. Plain `.txt` files never come here; the app sends them to Gemini
directly.

A single FastAPI service in one Docker container. No database, no user
accounts, no stored files: each request gets its own temporary folder,
deleted after the response.

## API

```
POST /convert/to-pdf
Content-Type: multipart/form-data, field "file"
Header: X-Firebase-AppCheck: <token>    (from the app)
Response: application/pdf (the PDF bytes)

GET /health  ->  {"status": "ok"}       (no authentication)
```

| Status | Meaning |
|---|---|
| 200 | PDF in the response body |
| 400 | No file, empty file, unsupported format, or content that does not match the format (for example a renamed file) |
| 401 | Missing or invalid App Check token / test key |
| 413 | Upload over 15 MB, or converted PDF over 30 MB |
| 422 | LibreOffice could not convert it (corrupt, password-protected) |
| 503 | Two conversions already running, or Google's keys unreachable; retry |
| 504 | Conversion took longer than 90 seconds |

## Authentication

The app sends a **Firebase App Check token** (Play Integrity) with every
request. The server checks it against Google's public keys
(`https://firebaseappcheck.googleapis.com/v1/jwks`, cached): signature
(RS256), expiry, issuer, audience and app ID. No service account or
Google secret is needed on the server; it only needs outgoing HTTPS to
`firebaseappcheck.googleapis.com`.

The optional **test key** (`X-API-Key`) is accepted only for requests made
from inside the container (address 127.0.0.1). Requests through the
reverse proxy come from the Docker network, so the key never works
through the public address. Leave it empty to switch it off.

## Environment variables

Copy `.env.example` to `/etc/forditva-converter.env` (`chmod 600`).

| Variable | Value | Notes |
|---|---|---|
| `FIREBASE_PROJECT_NUMBER` | `851863893438` | Project `forditva-151`. Public, required |
| `FIREBASE_APP_IDS` | `1:851863893438:android:c740e257fb79717cefb5ef` | Android app. Comma-separated if iOS is added. Public, required |
| `INTERNAL_TEST_API_KEY` | empty, or `openssl rand -hex 32` | Optional, only from inside the container |
| `MAX_UPLOAD_MB` | `15` | |
| `MAX_PDF_MB` | `30` | |
| `MAX_CONCURRENT` | `2` | Parallel conversions |
| `TIMEOUT_SECONDS` | `90` | Per conversion |

The server refuses to start if a required variable is missing.

## Build and run

```bash
docker build -t forditva-converter .

docker run -d --name forditva-converter --restart unless-stopped \
  --env-file /etc/forditva-converter.env \
  -p 127.0.0.1:8000:8000 \
  --memory=2g --cpus=2 --pids-limit=256 \
  --read-only --tmpfs /tmp:rw,size=512m \
  --cap-drop=ALL --security-opt no-new-privileges \
  forditva-converter
```

- Port 8000 is published on the host's loopback only; the reverse proxy
  forwards `https://convert.wir-in-ungarn.hu` to `127.0.0.1:8000`.
- Proxy settings: request body at most 16 MB, timeout at least 120 s,
  per-IP rate limit. Don't enable forwarded-header trust in uvicorn.
- The container runs as a non-root user with a read-only file system;
  all work happens in the `/tmp` tmpfs (512 MB covers two conversions at
  the limits).
- The container needs outgoing HTTPS for Google's public keys and nothing
  else.

## Test

```bash
# Health, through the proxy:
curl -fsS https://convert.wir-in-ungarn.hu/health

# Without a token, through the proxy: must return 401.
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  -F 'file=@example.docx' https://convert.wir-in-ungarn.hu/convert/to-pdf

# Real conversion with the test key, from inside the container
# (docker cp does not work with --read-only, so pipe the file in):
docker exec -i forditva-converter sh -c 'cat > /tmp/example.docx' < example.docx
docker exec forditva-converter sh -c \
  'curl -fsS -X POST -H "X-API-Key: $INTERNAL_TEST_API_KEY" \
   -F file=@/tmp/example.docx http://127.0.0.1:8000/convert/to-pdf \
   -o /tmp/example.pdf && head -c 5 /tmp/example.pdf'
# prints %PDF-

# The same test key through the proxy: must return 401.
```

Remove the test files afterwards: `docker exec forditva-converter rm /tmp/example.docx /tmp/example.pdf`.

Logs (`docker logs forditva-converter`) show the format, sizes and
duration of each conversion, never file names or content.

## Developer tests

```bash
pip install -r requirements-dev.txt
pytest
```

The real LibreOffice test runs only where `soffice` is installed (for
example inside the image); the others use stubs.
