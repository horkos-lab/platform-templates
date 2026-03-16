package config

import (
	"fmt"
	"log/slog"
	"os"
	"strings"
)

// MaxNameBytes is the maximum byte length accepted for an item name.
const MaxNameBytes = 256

type Config struct {
	// LogLevel holds the parsed slog level. Load() always produces a valid
	// value; the zero value is slog.LevelInfo.
	LogLevel    slog.Level
	Environment string
}

// Load reads configuration from environment variables.
// LOG_LEVEL accepts case-insensitive strings: DEBUG, INFO, WARN, ERROR.
// Invalid values are rejected with a fatal log so misconfiguration is caught
// at startup rather than silently defaulting to a wrong level.
func Load() *Config {
	level, err := parseLogLevel(getEnv("LOG_LEVEL", "INFO"))
	if err != nil {
		// Misconfigured log level is a deployment error — fail fast at init.
		fmt.Fprintf(os.Stderr, "config: invalid LOG_LEVEL: %v\n", err)
		os.Exit(1)
	}
	return &Config{
		LogLevel:    level,
		Environment: getEnv("ENVIRONMENT", "development"),
	}
}

// parseLogLevel normalises s to uppercase and delegates to slog.Level's
// standard UnmarshalText (Go 1.21+), which accepts DEBUG/INFO/WARN/ERROR
// case-insensitively and rejects unknown strings with a descriptive error.
func parseLogLevel(s string) (slog.Level, error) {
	var l slog.Level
	if err := l.UnmarshalText([]byte(strings.ToUpper(s))); err != nil {
		return slog.LevelInfo, fmt.Errorf("parse %q: %w", s, err)
	}
	return l, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
