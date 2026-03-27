package storage

import (
	"context"
	"io"
	"time"
)

// Backend defines the storage abstraction layer.
// Implementations: FilesystemBackend (local disk) and S3Backend (S3-compatible).
type Backend interface {
	// Write stores a file at the given path.
	Write(ctx context.Context, path string, reader io.Reader, contentType string) error

	// Read returns a reader for the file at the given path.
	Read(ctx context.Context, path string) (io.ReadCloser, error)

	// Delete removes a file at the given path.
	Delete(ctx context.Context, path string) error

	// Exists checks if a file exists at the given path.
	Exists(ctx context.Context, path string) (bool, error)

	// GetURL returns a URL for direct client access.
	// For filesystem: returns a local serve path.
	// For S3: returns a pre-signed URL with the given expiry.
	GetURL(ctx context.Context, path string, expiry time.Duration) (string, error)

	// GetSize returns the file size in bytes.
	GetSize(ctx context.Context, path string) (int64, error)
}
