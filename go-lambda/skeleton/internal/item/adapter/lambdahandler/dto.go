package lambdahandler

import (
	"time"

	"github.com/${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}/internal/item/domain"
)

// Request is the JSON payload sent to the Lambda function.
// Replace this with your actual event type when integrating with an event source
// (e.g. events.SQSEvent, events.EventBridgeEvent, a custom struct, etc.).
type Request struct {
	Action string `json:"action"`          // "create" | "list"
	Name   string `json:"name,omitempty"`  // required for action "create"
}

// Response is the JSON payload returned by the Lambda function.
// Business-logic errors are surfaced in the Error field so the caller can
// distinguish them from infrastructure failures (which return a Go error and
// cause Lambda to mark the invocation as failed).
type Response struct {
	Items []itemResponse `json:"items,omitempty"`
	Item  *itemResponse  `json:"item,omitempty"`
	Error string         `json:"error,omitempty"`
}

type itemResponse struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

func newItemResponse(i domain.Item) itemResponse {
	return itemResponse{ID: string(i.ID), Name: string(i.Name), CreatedAt: i.CreatedAt}
}

func newListResponse(items []domain.Item) Response {
	out := make([]itemResponse, len(items))
	for i, item := range items {
		out[i] = newItemResponse(item)
	}
	return Response{Items: out}
}
