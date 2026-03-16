package lambdahandler

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"runtime/debug"

	"github.com/aws/aws-lambda-go/lambdacontext"

	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/config"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/domain"
	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/port"
)

// Handler is the Lambda adapter. It translates direct-invocation JSON payloads
// into domain calls and maps results back to JSON responses.
// Replace Request/Response with your actual event types (SQS, EventBridge, etc.)
// if this function is triggered by an AWS event source.
type Handler struct {
	svc    port.ItemService
	logger *slog.Logger
}

// NewHandler constructs a Handler. Expensive resources (SDK clients, DB pools)
// should be initialised here — they are reused across warm invocations.
//
// Both svc and cfg are required. Passing nil is a programming error; this
// constructor panics in that case following the must-style convention used by
// the standard library (regexp.MustCompile, template.Must, etc.) for
// constructors that cannot return an error. Panics surface immediately in
// tests and during process startup, making misconfiguration impossible to miss.
func NewHandler(svc port.ItemService, cfg *config.Config) *Handler {
	if svc == nil {
		panic("lambdahandler.NewHandler: svc must not be nil")
	}
	if cfg == nil {
		panic("lambdahandler.NewHandler: cfg must not be nil")
	}
	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: cfg.LogLevel}))
	return &Handler{svc: svc, logger: logger}
}

// Handle is the Lambda entry point. Panics are caught and converted to Go
// errors so the function fails cleanly instead of crashing the process.
//
// Error semantics — two distinct categories:
//
//  1. Application errors (validation failures, domain rule violations, resource
//     not found): returned in Response.Error with a nil Go error. The Lambda
//     invocation is marked *successful*; the caller decides how to react.
//
//  2. Infrastructure / unexpected errors (panics, unhandled service failures):
//     returned as a non-nil Go error. Lambda marks the invocation as *failed*,
//     which enables retries, DLQ routing, and CloudWatch alarms.
func (h *Handler) Handle(ctx context.Context, req Request) (resp Response, err error) {
	defer func() {
		if r := recover(); r != nil {
			h.logger.ErrorContext(ctx, "panic recovered",
				slog.Any("panic", r),
				slog.String("stack", string(debug.Stack())),
			)
			err = fmt.Errorf("internal error")
		}
	}()

	log := h.requestLogger(ctx)
	log.InfoContext(ctx, "invocation", slog.String("action", req.Action))

	switch req.Action {
	case "create":
		return h.createItem(ctx, log, req)
	case "list":
		return h.listItems(ctx, log)
	default:
		return Response{Error: fmt.Sprintf("unknown action %q; valid: create, list", req.Action)}, nil
	}
}

func (h *Handler) requestLogger(ctx context.Context) *slog.Logger {
	log := h.logger
	if lc, ok := lambdacontext.FromContext(ctx); ok {
		log = log.With(
			slog.String("lambda_request_id", lc.AwsRequestID),
			slog.String("function_arn", lc.InvokedFunctionArn),
		)
	}
	return log
}

// listItems fetches all items. Service errors are treated as application-level
// outcomes and surfaced in Response.Error (not as a Go error) so that the
// Lambda invocation is recorded as successful and the caller can handle the
// condition without triggering retry / DLQ logic.
func (h *Handler) listItems(ctx context.Context, log *slog.Logger) (Response, error) {
	items, err := h.svc.ListItems(ctx)
	if err != nil {
		log.ErrorContext(ctx, "list items failed", slog.String("error", err.Error()))
		return Response{Error: safeErrorMessage(err)}, nil
	}
	return newListResponse(items), nil
}

func (h *Handler) createItem(ctx context.Context, log *slog.Logger, req Request) (Response, error) {
	if len(req.Name) > config.MaxNameBytes {
		return Response{Error: fmt.Sprintf("name exceeds maximum length of %d bytes", config.MaxNameBytes)}, nil
	}

	item, err := h.svc.CreateItem(ctx, req.Name)
	if err != nil {
		log.WarnContext(ctx, "create item failed",
			slog.String("error", err.Error()),
			slog.String("name", req.Name),
		)
		return Response{Error: safeErrorMessage(err)}, nil
	}

	log.InfoContext(ctx, "item created", slog.String("item_id", string(item.ID)))
	resp := newItemResponse(item)
	return Response{Item: &resp}, nil
}

// safeErrorMessage maps known domain errors to their clean, user-safe messages
// and returns a generic message for any unexpected error, preventing internal
// implementation details from leaking to callers (OWASP: Improper Error
// Handling / Information Exposure). The raw error is always logged before this
// function is called so internal context is preserved for debugging.
func safeErrorMessage(err error) string {
	// Known domain errors carry messages that are already safe to expose.
	switch {
	case errors.Is(err, domain.ErrEmptyName):
		return domain.ErrEmptyName.Error() // "name cannot be empty"
	case errors.Is(err, domain.ErrItemNotFound):
		return domain.ErrItemNotFound.Error() // "item not found"
	}
	// Unknown / infrastructure errors: return a generic message. The caller
	// receives no internal detail; the full error is already in the logs.
	return "an unexpected error occurred; please try again later"
}
