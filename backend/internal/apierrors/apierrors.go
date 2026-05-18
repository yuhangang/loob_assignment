package apierrors

import (
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/labstack/echo/v4"
	"github.com/loob/backend/internal/contextx"
)

const (
	CodeBadRequest      = "API_BAD_REQUEST"
	CodeUnauthorized    = "API_UNAUTHORIZED"
	CodeForbidden       = "API_FORBIDDEN"
	CodeNotFound        = "API_NOT_FOUND"
	CodeConflict        = "API_CONFLICT"
	CodeUnprocessable   = "API_UNPROCESSABLE"
	CodeInternal        = "API_INTERNAL_ERROR"
	CodeRequestTooLarge = "API_REQUEST_TOO_LARGE"
	CodeRateLimited     = "API_RATE_LIMITED"
)

type Response struct {
	Error     string `json:"error"`
	ErrorCode string `json:"error_code"`
	TraceID   string `json:"trace_id,omitempty"`
}

func New(status int, code, message string) *echo.HTTPError {
	return echo.NewHTTPError(status, Response{
		Error:     message,
		ErrorCode: strings.TrimSpace(code),
	})
}

func Handler(err error, c echo.Context) {
	if c.Response().Committed {
		return
	}

	status := http.StatusInternalServerError
	resp := Response{
		Error:     http.StatusText(status),
		ErrorCode: CodeInternal,
	}

	if he, ok := err.(*echo.HTTPError); ok {
		status = he.Code
		resp.ErrorCode = defaultCode(status)
		resp.Error = messageForStatus(status)
		mergeMessage(&resp, he.Message)
		if he.Internal != nil {
			err = he.Internal
		}
	}

	if strings.TrimSpace(resp.ErrorCode) == "" {
		resp.ErrorCode = defaultCode(status)
	}
	if strings.TrimSpace(resp.Error) == "" {
		resp.Error = messageForStatus(status)
	}

	rc := contextx.FromEcho(c)
	resp.TraceID = rc.TraceID

	if status >= http.StatusInternalServerError {
		log.Printf("trace_id=%s country=%s status=%d error_code=%s error=%v", rc.TraceID, rc.CountryCode, status, resp.ErrorCode, err)
	}

	if jsonErr := c.JSON(status, resp); jsonErr != nil {
		c.Logger().Error(jsonErr)
	}
}

func mergeMessage(resp *Response, msg interface{}) {
	switch v := msg.(type) {
	case Response:
		if v.Error != "" {
			resp.Error = v.Error
		}
		if v.ErrorCode != "" {
			resp.ErrorCode = v.ErrorCode
		}
	case *Response:
		if v != nil {
			mergeMessage(resp, *v)
		}
	case map[string]string:
		if v["error"] != "" {
			resp.Error = v["error"]
		} else if v["message"] != "" {
			resp.Error = v["message"]
		}
		if v["error_code"] != "" {
			resp.ErrorCode = v["error_code"]
		} else if v["code"] != "" {
			resp.ErrorCode = v["code"]
		}
	case map[string]interface{}:
		if raw, ok := v["error"]; ok {
			resp.Error = fmt.Sprint(raw)
		} else if raw, ok := v["message"]; ok {
			resp.Error = fmt.Sprint(raw)
		}
		if raw, ok := v["error_code"]; ok {
			resp.ErrorCode = fmt.Sprint(raw)
		} else if raw, ok := v["code"]; ok {
			resp.ErrorCode = fmt.Sprint(raw)
		}
	case string:
		if v != "" {
			resp.Error = v
		}
	default:
		if v != nil {
			resp.Error = fmt.Sprint(v)
		}
	}
}

func messageForStatus(status int) string {
	if text := http.StatusText(status); text != "" {
		return text
	}
	return http.StatusText(http.StatusInternalServerError)
}

func defaultCode(status int) string {
	switch status {
	case http.StatusBadRequest:
		return CodeBadRequest
	case http.StatusUnauthorized:
		return CodeUnauthorized
	case http.StatusForbidden:
		return CodeForbidden
	case http.StatusNotFound:
		return CodeNotFound
	case http.StatusConflict:
		return CodeConflict
	case http.StatusUnprocessableEntity:
		return CodeUnprocessable
	case http.StatusRequestEntityTooLarge:
		return CodeRequestTooLarge
	case http.StatusTooManyRequests:
		return CodeRateLimited
	default:
		return CodeInternal
	}
}
