FROM python:3.14-slim

ENV TZ=Europe/Prague

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends xvfb xauth tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && playwright install --with-deps chromium

COPY . .

CMD ["sh", "-c", "Xvfb :99 -screen 0 1280x1024x24 -ac -nolisten tcp & sleep 2 && DISPLAY=:99 python kontrola_ceny.py"]
