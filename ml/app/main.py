"""Reframe ML Sidecar — Face recognition, visual search, and OCR."""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI

# from app.api import faces, clip, ocr, health


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load ML models on startup, release on shutdown."""
    print("Reframe ML Sidecar starting...")
    print(f"Model path: {os.getenv('REFRAME_ML_MODEL_PATH', '/models')}")
    print(f"Device: {os.getenv('REFRAME_ML_DEVICE', 'cpu')}")

    # TODO: Phase 3 implementation
    # - Load InsightFace SCRFD face detection model
    # - Load ArcFace face embedding model
    # - Load CLIP ViT-B/32 image + text encoders
    # - Initialize Tesseract OCR engine
    # - Warm up models with dummy inference

    yield

    # Cleanup
    print("Reframe ML Sidecar shutting down...")


app = FastAPI(
    title="Reframe ML Sidecar",
    description="Face recognition, visual search (CLIP), and OCR services for Reframe.",
    version="0.0.1",
    lifespan=lifespan,
)


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {
        "status": "ok",
        "version": "0.0.1-dev",
        "models": {
            "face_detection": False,  # TODO: report actual model status
            "face_embedding": False,
            "clip": False,
            "ocr": False,
        },
    }


# TODO: Phase 3 — register route handlers
# app.include_router(faces.router, prefix="/api/faces", tags=["faces"])
# app.include_router(clip.router, prefix="/api/clip", tags=["clip"])
# app.include_router(ocr.router, prefix="/api/ocr", tags=["ocr"])
