package lambdahandler_test

import (
	"context"
	"log/slog"
	"testing"

	"github.com/aws/aws-lambda-go/lambdacontext"

	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/config"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/adapter/lambdahandler"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/adapter/memory"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/domain"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/service"
)

type panicService struct{}

func (p *panicService) CreateItem(_ context.Context, _ string) (domain.Item, error) {
	return domain.Item{}, nil
}
func (p *panicService) ListItems(_ context.Context) ([]domain.Item, error) {
	panic("simulated panic")
}

func newHandler() *lambdahandler.Handler {
	repo := memory.NewRepository()
	svc := service.NewItemService(repo)
	return lambdahandler.NewHandler(svc, &config.Config{LogLevel: slog.LevelInfo, Environment: "test"})
}

func lambdaCtx(awsRequestID string) context.Context {
	lc := &lambdacontext.LambdaContext{AwsRequestID: awsRequestID}
	return lambdacontext.NewContext(context.Background(), lc)
}

func TestHandle_Actions(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name      string
		req       lambdahandler.Request
		wantErr   bool
		wantItem  bool
		wantItems bool
		wantError string
	}{
		{
			name:      "list empty",
			req:       lambdahandler.Request{Action: "list"},
			wantItems: true,
		},
		{
			name:     "create valid",
			req:      lambdahandler.Request{Action: "create", Name: "widget"},
			wantItem: true,
		},
		{
			name:      "create empty name",
			req:       lambdahandler.Request{Action: "create", Name: ""},
			wantError: "cannot be empty",
		},
		{
			name:      "unknown action",
			req:       lambdahandler.Request{Action: "delete"},
			wantError: "unknown action",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			h := newHandler()
			resp, err := h.Handle(lambdaCtx("req-"+tc.name), tc.req)

			if tc.wantErr && err == nil {
				t.Fatal("want error, got nil")
			}
			if !tc.wantErr && err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if tc.wantItem && resp.Item == nil {
				t.Fatal("want Item in response, got nil")
			}
			if tc.wantItems && resp.Items == nil {
				t.Fatal("want Items in response, got nil")
			}
			if tc.wantError != "" && resp.Error == "" {
				t.Fatalf("want Error field containing %q, got empty", tc.wantError)
			}
		})
	}
}

func TestHandle_CreateThenList(t *testing.T) {
	t.Parallel()

	h := newHandler()
	ctx := lambdaCtx("req-integration")

	for _, name := range []string{"alpha", "beta", "gamma"} {
		resp, err := h.Handle(ctx, lambdahandler.Request{Action: "create", Name: name})
		if err != nil || resp.Item == nil {
			t.Fatalf("create %q: err=%v item=%v", name, err, resp.Item)
		}
	}

	resp, err := h.Handle(ctx, lambdahandler.Request{Action: "list"})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(resp.Items) != 3 {
		t.Fatalf("want 3 items, got %d", len(resp.Items))
	}
}

func TestHandle_NameTooLong(t *testing.T) {
	t.Parallel()

	h := newHandler()
	longName := string(make([]byte, config.MaxNameBytes+1))
	resp, err := h.Handle(lambdaCtx("req-toolong"), lambdahandler.Request{Action: "create", Name: longName})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Error == "" {
		t.Fatal("want Error field for oversized name")
	}
}

func TestHandle_PanicRecovery(t *testing.T) {
	t.Parallel()

	h := lambdahandler.NewHandler(&panicService{}, &config.Config{LogLevel: slog.LevelInfo, Environment: "test"})
	_, err := h.Handle(lambdaCtx("req-panic"), lambdahandler.Request{Action: "list"})
	if err == nil {
		t.Fatal("want error after panic recovery, got nil")
	}
}
