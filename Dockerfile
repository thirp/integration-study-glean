FROM python:3.12.14-slim
WORKDIR /study
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY connector.py wiki.py probe.py evidence.py ./
COPY fixtures fixtures

COPY expected expected
