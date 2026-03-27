FROM python:3.11-slim-bookworm

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    tesseract-ocr \
    tesseract-ocr-eng \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY pyproject.toml ./
RUN pip install --no-cache-dir -e . 2>/dev/null || \
    pip install --no-cache-dir \
    fastapi \
    uvicorn[standard] \
    onnxruntime \
    insightface \
    numpy \
    Pillow \
    pytesseract \
    httpx

COPY app/ ./app/

# Create model cache directory
RUN mkdir -p /models

ENV REFRAME_ML_MODEL_PATH=/models

EXPOSE 8100

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8100"]
