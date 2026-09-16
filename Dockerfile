FROM python:3.14-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r  requirements.txt
RUN apt-get update && apt-get install -y xvfb xauth
RUN pip install playwright && playwright install --with-deps chromium
COPY . .
CMD ["sh", "-c", "Xvfb :99 -screen 0 1280x1024x24 -ac -nolisten tcp & sleep 2 && DISPLAY=:99 python kontrola_ceny.py"]
