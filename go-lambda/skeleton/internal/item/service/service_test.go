package service_test

import (
	"context"
	"errors"
	"testing"

	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/domain"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/port"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/service"
)

// Compile-time assertion: stubRepo satisfies the ItemRepository port.
var _ port.ItemRepository = (*stubRepo)(nil)

type stubRepo struct {
	items   []domain.Item
	saveErr error
}

func (s *stubRepo) CreateItem(_ context.Context, item domain.Item) error {
	if s.saveErr != nil {
		return s.saveErr
	}
	s.items = append(s.items, item)
	return nil
}

func (s *stubRepo) ListItems(_ context.Context) ([]domain.Item, error) {
	return s.items, nil
}

func TestCreateItem(t *testing.T) {
	t.Parallel()

	repoErr := errors.New("storage unavailable")

	tests := []struct {
		name      string
		inputName string
		repoErr   error
		wantErr   error
		wantName  string
	}{
		{
			name:      "success",
			inputName: "widget",
			wantName:  "widget",
		},
		{
			name:      "whitespace is trimmed and accepted",
			inputName: "  gadget  ",
			wantName:  "gadget",
		},
		{
			name:      "empty name returns domain error",
			inputName: "",
			wantErr:   domain.ErrEmptyName,
		},
		{
			name:      "whitespace-only name returns domain error",
			inputName: "   ",
			wantErr:   domain.ErrEmptyName,
		},
		{
			name:      "repository error is propagated",
			inputName: "widget",
			repoErr:   repoErr,
			wantErr:   repoErr,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			svc := service.NewItemService(&stubRepo{saveErr: tc.repoErr})
			item, err := svc.CreateItem(context.Background(), tc.inputName)

			if tc.wantErr != nil {
				if !errors.Is(err, tc.wantErr) {
					t.Fatalf("CreateItem(%q): error = %v, want %v", tc.inputName, err, tc.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatalf("CreateItem(%q): unexpected error: %v", tc.inputName, err)
			}
			if string(item.ID) == "" {
				t.Fatal("CreateItem: ID is empty")
			}
			if string(item.Name) != tc.wantName {
				t.Fatalf("CreateItem: Name = %q, want %q", item.Name, tc.wantName)
			}
		})
	}
}

func TestListItems(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name        string
		seedNames   []string
		wantCount   int
	}{
		{name: "empty repository returns empty slice", seedNames: nil, wantCount: 0},
		{name: "single item", seedNames: []string{"alpha"}, wantCount: 1},
		{name: "multiple items", seedNames: []string{"alpha", "beta", "gamma"}, wantCount: 3},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			repo := &stubRepo{}
			svc := service.NewItemService(repo)

			for _, n := range tc.seedNames {
				if _, err := svc.CreateItem(context.Background(), n); err != nil {
					t.Fatalf("seed CreateItem(%q): %v", n, err)
				}
			}

			items, err := svc.ListItems(context.Background())
			if err != nil {
				t.Fatalf("ListItems: unexpected error: %v", err)
			}
			if len(items) != tc.wantCount {
				t.Fatalf("ListItems: got %d items, want %d", len(items), tc.wantCount)
			}
		})
	}
}
