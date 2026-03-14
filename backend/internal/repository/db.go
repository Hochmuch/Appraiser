package repository

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	_ "github.com/lib/pq"
)

func NewDB() (*sql.DB, error) {
	host := getEnv("DB_HOST", "localhost")
	port := getEnv("DB_PORT", "5432")
	user := getEnv("DB_USER", "appraiser")
	password := getEnv("DB_PASSWORD", "appraiser")
	dbname := getEnv("DB_NAME", "appraiser")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, err
	}

	if err := db.Ping(); err != nil {
		return nil, err
	}

	return db, nil
}

func RunMigrations(db *sql.DB, migrationsPath string) error {
	entries, err := os.ReadDir(migrationsPath)
	if err != nil {
		return fmt.Errorf("reading migration directory: %w", err)
	}

	var files []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if strings.HasSuffix(entry.Name(), ".sql") {
			files = append(files, filepath.Join(migrationsPath, entry.Name()))
		}
	}

	sort.Strings(files)

	for _, filePath := range files {
		data, err := os.ReadFile(filePath)
		if err != nil {
			return fmt.Errorf("reading migration file %s: %w", filePath, err)
		}

		if _, err := db.Exec(string(data)); err != nil {
			return fmt.Errorf("executing migration %s: %w", filePath, err)
		}
	}

	return nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
