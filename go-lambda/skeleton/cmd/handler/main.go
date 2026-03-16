package main

// Build with: -tags lambda.norpc
// This disables the net/rpc server that aws-lambda-go starts by default,
// shaving ~3 ms off every cold start and eliminating an unused listener.

import (
	"log/slog"
	"os"

	"github.com/aws/aws-lambda-go/lambda"

	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/config"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/adapter/lambdahandler"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/adapter/memory"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/service"
)

// h is initialised once during the Lambda init phase. Expensive resources
// (SDK clients, DB pools, etc.) should be constructed here so they are reused
// across warm invocations rather than recreated on every event.
var h *lambdahandler.Handler

func init() {
	cfg := config.Load()

	// Initialise a temporary bootstrap logger so that any init-phase errors
	// are emitted as structured JSON before the handler logger is available.
	initLog := slog.New(slog.NewJSONHandler(os.Stderr, nil))

	repo := memory.NewRepository()
	svc := service.NewItemService(repo)
	h = lambdahandler.NewHandler(svc, cfg)

	initLog.Info("lambda initialised",
		slog.String("env", cfg.Environment),
		slog.String("log_level", cfg.LogLevel.String()),
	)
}

func main() {
	lambda.Start(h.Handle)
}
