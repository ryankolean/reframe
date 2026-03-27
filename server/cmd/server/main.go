package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Println("Reframe server starting...")
	fmt.Printf("Version: %s\n", version())

	// TODO: Phase 1 implementation
	// - Load configuration (Viper)
	// - Initialize SQLite database + run migrations
	// - Initialize storage backend
	// - Initialize background job workers
	// - Set up Gin router with middleware
	// - Register API handlers
	// - Start HTTP server

	fmt.Println("Reframe server is not yet implemented. See docs/DESIGN.md for the full specification.")
	os.Exit(0)
}

func version() string {
	return "0.0.1-dev"
}
