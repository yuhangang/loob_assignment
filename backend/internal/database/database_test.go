package database

import (
	"database/sql"
	"database/sql/driver"
	"io"
	"os"
	"path/filepath"
	"testing"
)

// A minimal mock SQL driver to test DB interactions without MySQL.
type mockDriver struct{}

func (d *mockDriver) Open(name string) (driver.Conn, error) {
	return &mockConn{}, nil
}

type mockConn struct{}

func (c *mockConn) Prepare(query string) (driver.Stmt, error) {
	return &mockStmt{}, nil
}

func (c *mockConn) Close() error {
	return nil
}

func (c *mockConn) Begin() (driver.Tx, error) {
	return &mockTx{}, nil
}

type mockStmt struct{}

func (s *mockStmt) Close() error {
	return nil
}

func (s *mockStmt) NumInput() int {
	return -1
}

func (s *mockStmt) Exec(args []driver.Value) (driver.Result, error) {
	return &mockResult{}, nil
}

func (s *mockStmt) Query(args []driver.Value) (driver.Rows, error) {
	return &mockRows{index: 0}, nil
}

type mockResult struct{}

func (r *mockResult) LastInsertId() (int64, error) { return 1, nil }
func (r *mockResult) RowsAffected() (int64, error) { return 1, nil }

type mockRows struct {
	index int
}

func (r *mockRows) Columns() []string {
	return []string{"1"}
}

func (r *mockRows) Close() error {
	return nil
}

func (r *mockRows) Next(dest []driver.Value) error {
	if r.index > 0 {
		return io.EOF
	}
	r.index++
	dest[0] = int64(1)
	return nil
}

type mockTx struct{}

func (t *mockTx) Commit() error {
	return nil
}

func (t *mockTx) Rollback() error {
	return nil
}

func init() {
	sql.Register("mock_driver", &mockDriver{})
}

func TestOpen_InvalidDSN(t *testing.T) {
	// This will fail on Ping because the DSN is completely invalid for the MySQL driver,
	// or the server is not running.
	db, err := Open("invalid_dsn")
	if err == nil {
		t.Error("expected error for invalid DSN, got nil")
	}
	if db != nil {
		db.Close()
	}
}

func TestRunMigrations_EmptyDir(t *testing.T) {
	db, err := sql.Open("mock_driver", "")
	if err != nil {
		t.Fatalf("failed to open mock db: %v", err)
	}
	defer db.Close()

	err = RunMigrations(db, "")
	if err == nil {
		t.Error("expected error for empty migrations directory, got nil")
	}
	if err.Error() != "migrations directory is required" {
		t.Errorf("expected 'migrations directory is required' error, got %v", err)
	}
}

func TestRunMigrations_NonExistentDir(t *testing.T) {
	db, err := sql.Open("mock_driver", "")
	if err != nil {
		t.Fatalf("failed to open mock db: %v", err)
	}
	defer db.Close()

	err = RunMigrations(db, "non_existent_directory_xyz")
	if err == nil {
		t.Error("expected error for non-existent migrations directory, got nil")
	}
}

func TestRunMigrations_SuccessWithMock(t *testing.T) {
	db, err := sql.Open("mock_driver", "")
	if err != nil {
		t.Fatalf("failed to open mock db: %v", err)
	}
	defer db.Close()

	// Create a temp migrations directory with some dummy SQL files
	tmpDir, err := os.MkdirTemp("", "migrations")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	f1 := filepath.Join(tmpDir, "0001_init.sql")
	if err := os.WriteFile(f1, []byte("CREATE TABLE x;"), 0644); err != nil {
		t.Fatalf("failed to write dummy migration: %v", err)
	}

	err = RunMigrations(db, tmpDir)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
}

func TestMigrationApplied(t *testing.T) {
	db, err := sql.Open("mock_driver", "")
	if err != nil {
		t.Fatalf("failed to open mock db: %v", err)
	}
	defer db.Close()

	applied, err := migrationApplied(db, "0001_init.sql")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !applied {
		t.Error("expected migration to be applied (since mock always returns rows), got false")
	}
}
