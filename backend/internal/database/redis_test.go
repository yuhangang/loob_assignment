package database

import (
	"bufio"
	"bytes"
	"io"
	"testing"
)

func TestSerializeCommand(t *testing.T) {
	tests := []struct {
		args     []string
		expected string
	}{
		{[]string{"PING"}, "*1\r\n$4\r\nPING\r\n"},
		{[]string{"GET", "mykey"}, "*2\r\n$3\r\nGET\r\n$5\r\nmykey\r\n"},
		{[]string{"SET", "key", "val", "EX", "60"}, "*5\r\n$3\r\nSET\r\n$3\r\nkey\r\n$3\r\nval\r\n$2\r\nEX\r\n$2\r\n60\r\n"},
	}

	for _, tc := range tests {
		actual := string(serializeCommand(tc.args...))
		if actual != tc.expected {
			t.Errorf("serializeCommand(%v) = %q, expected %q", tc.args, actual, tc.expected)
		}
	}
}

func TestRespReader_ReadResponse(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected any
		err      bool
	}{
		{"SimpleString", "+OK\r\n", "OK", false},
		{"Error", "-ERR message\r\n", nil, true},
		{"Integer", ":12345\r\n", int64(12345), false},
		{"BulkString", "$5\r\nhello\r\n", "hello", false},
		{"NullBulkString", "$-1\r\n", nil, false},
		{"Array", "*2\r\n$5\r\nhello\r\n:100\r\n", []any{"hello", int64(100)}, false},
		{"EmptyArray", "*0\r\n", []any{}, false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			buf := bytes.NewReader([]byte(tc.input))
			reader := &respReader{bufioReaderHelper(buf)}
			val, err := reader.readResponse()
			if (err != nil) != tc.err {
				t.Fatalf("unexpected error state: got %v, expected err=%v", err, tc.err)
			}
			if tc.err {
				return
			}
			if tc.expected == nil {
				if val != nil {
					t.Errorf("got %v, expected nil", val)
				}
				return
			}

			switch expectedVal := tc.expected.(type) {
			case string:
				if val != expectedVal {
					t.Errorf("got %v, expected %v", val, expectedVal)
				}
			case int64:
				if val != expectedVal {
					t.Errorf("got %v, expected %v", val, expectedVal)
				}
			case []any:
				actualArr, ok := val.([]any)
				if !ok {
					t.Fatalf("unexpected type returned: %T", val)
				}
				if len(actualArr) != len(expectedVal) {
					t.Fatalf("array len got %d, expected %d", len(actualArr), len(expectedVal))
				}
				for i, v := range expectedVal {
					if actualArr[i] != v {
						t.Errorf("index %d: got %v, expected %v", i, actualArr[i], v)
					}
				}
			}
		})
	}
}

func bufioReaderHelper(r io.Reader) *bufio.Reader {
	return bufio.NewReader(r)
}
