# Contributing to Reframe

Thank you for your interest in contributing to Reframe! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, constructive, and inclusive. We're building something for families — let's keep the community family-friendly too.

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Use the bug report issue template
3. Include: OS, Docker version, browser/device, steps to reproduce, expected vs actual behavior
4. Include logs if applicable (`docker compose logs reframe`)

### Suggesting Features

1. Check existing issues and the roadmap in the design doc
2. Use the feature request issue template
3. Describe the use case, not just the solution

### Submitting Code

1. Fork the repository
2. Create a feature branch from `develop`: `git checkout -b feature/your-feature`
3. Make your changes following the code standards below
4. Write tests for new functionality
5. Run the test suite locally
6. Commit using [Conventional Commits](https://www.conventionalcommits.org/)
7. Push and open a Pull Request against `develop`

## Development Setup

### Prerequisites

- Go 1.22+
- Python 3.11+
- Node.js 20+
- Docker + Docker Compose
- FFmpeg 6+

### Local Development

```bash
# Backend
cd server
go mod download
go run cmd/server/main.go

# ML Sidecar
cd ml
python -m venv venv
source venv/bin/activate
pip install -e .
uvicorn app.main:app --reload --port 8100

# Web Client
cd web
npm install
npm run dev

# Mobile
cd mobile
npm install
npx expo start
```

## Code Standards

### Go

- Format with `gofmt`
- Lint with `golangci-lint`
- Test with `go test ./...`
- Error handling: always handle errors, never use `_` for error returns

### Python

- Format with Black
- Lint with Ruff
- Type check with mypy (strict mode)
- Test with pytest

### TypeScript / React

- ESLint + Prettier
- Strict TypeScript (`strict: true`)
- Functional components with hooks
- Zustand for state management

### Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add face merge functionality
fix: resolve thumbnail generation for HEIC files
docs: update API reference for share endpoints
chore: upgrade FFmpeg to 6.1
test: add integration tests for upload pipeline
```

### Branching

- `main` — Stable releases only
- `develop` — Integration branch
- `feature/*` — Feature branches (from `develop`)
- `fix/*` — Bug fix branches (from `develop`)
- `release/*` — Release preparation (from `develop` to `main`)

## Architecture Decisions

Major architecture changes should be discussed in an issue first. Reference the [Design Document](docs/DESIGN.md) for current architecture decisions and rationale.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
