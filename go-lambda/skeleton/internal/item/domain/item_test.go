package domain_test

import (
	"testing"
	"time"

	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/domain"
)

func TestNewName(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		input   string
		want    string
		wantErr bool
	}{
		{name: "valid name", input: "widget", want: "widget"},
		{name: "trims leading and trailing spaces", input: "  widget  ", want: "widget"},
		{name: "empty string", input: "", wantErr: true},
		{name: "whitespace only", input: "   ", wantErr: true},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got, err := domain.NewName(tc.input)
			if tc.wantErr {
				if err == nil {
					t.Fatalf("NewName(%q): expected error, got nil", tc.input)
				}
				return
			}
			if err != nil {
				t.Fatalf("NewName(%q): unexpected error: %v", tc.input, err)
			}
			if string(got) != tc.want {
				t.Fatalf("NewName(%q) = %q, want %q", tc.input, got, tc.want)
			}
		})
	}
}

func TestNewID(t *testing.T) {
	t.Parallel()

	t.Run("non-empty", func(t *testing.T) {
		t.Parallel()
		id := domain.NewID()
		if string(id) == "" {
			t.Fatal("NewID() returned empty string")
		}
	})

	t.Run("unique across calls", func(t *testing.T) {
		t.Parallel()
		id1 := domain.NewID()
		id2 := domain.NewID()
		if id1 == id2 {
			t.Fatalf("NewID() returned duplicate value %q", id1)
		}
	})
}

func TestNewItem(t *testing.T) {
	t.Parallel()

	name, err := domain.NewName("widget")
	if err != nil {
		t.Fatalf("NewName: %v", err)
	}

	before := time.Now().UTC()
	item := domain.NewItem(name)
	after := time.Now().UTC()

	if string(item.ID) == "" {
		t.Fatal("NewItem: ID is empty")
	}
	if item.Name != name {
		t.Fatalf("NewItem: Name = %q, want %q", item.Name, name)
	}
	if item.CreatedAt.IsZero() {
		t.Fatal("NewItem: CreatedAt is zero")
	}
	if item.CreatedAt.Before(before) || item.CreatedAt.After(after) {
		t.Fatalf("NewItem: CreatedAt %v is outside [%v, %v]", item.CreatedAt, before, after)
	}
}
