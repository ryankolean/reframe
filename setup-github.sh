#!/bin/bash
# Reframe — GitHub Repository Setup Script
# Run this from the reframe/ directory after downloading
#
# Prerequisites:
#   - git installed
#   - GitHub CLI (gh) installed, OR a GitHub Personal Access Token
#
# Usage:
#   chmod +x setup-github.sh
#   ./setup-github.sh

set -e

REPO_NAME="reframe"
GITHUB_USER="ryankolean"
DESCRIPTION="Open-source, self-hosted Google Photos alternative. Your photos, your server, your rules."

echo "=== Reframe GitHub Repository Setup ==="
echo ""

# Check if gh CLI is available
if command -v gh &> /dev/null; then
    echo "Creating GitHub repository via gh CLI..."
    gh repo create "$REPO_NAME" \
        --public \
        --description "$DESCRIPTION" \
        --clone=false \
        2>/dev/null || echo "Repository may already exist, continuing..."
else
    echo "GitHub CLI (gh) not found."
    echo "Please create the repo manually at https://github.com/new"
    echo "  Name: $REPO_NAME"
    echo "  Visibility: Public"
    echo ""
    echo "Or install gh: https://cli.github.com/"
    echo ""
    read -p "Press Enter once the repo is created on GitHub..."
fi

echo ""
echo "Initializing local git repository..."

# Initialize git if not already
if [ ! -d ".git" ]; then
    git init
fi

# Add all files
git add .

# Create initial commit
git commit -m "feat: initial project scaffold

- Complete design document (docs/DESIGN.md) — 1200+ line architecture spec
- Go backend scaffold with storage abstraction and SQLite migration
- Python ML sidecar scaffold (FastAPI, InsightFace, CLIP, Tesseract)
- React web client scaffold (Vite, TypeScript, Tailwind, React Router)
- React Native mobile scaffold (Expo, background sync deps)
- Docker Compose setup (Go + ML + Redis + Caddy)
- CI/CD workflows (lint, test, Docker build, release)
- Plugin system template
- Documentation (API, deployment, development, plugins)
- Issue templates (bug report, feature request)
- MIT License"

# Set main branch
git branch -M main

# Add remote
git remote add origin "https://github.com/${GITHUB_USER}/${REPO_NAME}.git" 2>/dev/null || \
    git remote set-url origin "https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

# Push
echo ""
echo "Pushing to GitHub..."
git push -u origin main

echo ""
echo "=== Done! ==="
echo "Repository: https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo ""
echo "Next steps:"
echo "  1. Review the design doc: docs/DESIGN.md"
echo "  2. Start Phase 1 development with Claude Code"
echo "  3. Share the repo URL with collaborators"
