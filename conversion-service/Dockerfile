FROM python:3.12-slim-bookworm

# LibreOffice (Writer + Calc only) and fonts. Carlito and Caladea have the
# same metrics as Calibri and Cambria, the Word defaults, so page layout
# stays close to the original.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libreoffice-writer-nogui \
        libreoffice-calc-nogui \
        fonts-liberation \
        fonts-crosextra-carlito \
        fonts-crosextra-caladea \
        fonts-dejavu-core \
        curl \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --system --create-home --home-dir /home/converter converter

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY server.py .

USER converter
ENV HOME=/tmp PYTHONUNBUFFERED=1

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8000/health || exit 1

# No --proxy-headers: the test key relies on the real client address.
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
