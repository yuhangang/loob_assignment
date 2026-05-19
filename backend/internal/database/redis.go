package database

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"strconv"
	"sync"
	"time"
)

var (
	// RedisClientInstance is the global shared Redis client.
	RedisClientInstance *RedisClient

	// ErrNil is returned when a key does not exist, matching go-redis.Nil behavior.
	ErrNil = errors.New("redis: nil")
)

// RedisClient represents our custom zero-dependency connection pooled Redis client.
type RedisClient struct {
	addr                string
	pool                chan net.Conn
	active              chan struct{}
	mu                  sync.RWMutex
	DialFn              func(network, addr string) (net.Conn, error)
	brokenUntil         time.Time
	consecutiveFailures int
}

// InitRedis initializes the connection pool to the Redis server.
func InitRedis() {
	host := os.Getenv("REDIS_HOST")
	if host == "" {
		host = "127.0.0.1"
	}
	port := os.Getenv("REDIS_PORT")
	if port == "" {
		port = "6379"
	}
	addr := host + ":" + port

	idleSize := intEnv("REDIS_POOL_SIZE", 10)
	maxActive := intEnv("REDIS_MAX_ACTIVE", 100)

	log.Printf("Connecting to Redis at %s...", addr)
	client, err := NewRedisClientWithLimits(addr, idleSize, maxActive)
	if err != nil {
		log.Printf("Failed to connect to Redis pool (running in database-only fallback mode): %v", err)
		RedisClientInstance = nil
	} else {
		log.Printf("Successfully initialized connection pool to Redis at %s", addr)
		RedisClientInstance = client
	}
}

// NewRedisClient creates a new custom connection-pooled Redis client.
func NewRedisClient(addr string, poolSize int) (*RedisClient, error) {
	return NewRedisClientWithLimits(addr, poolSize, poolSize)
}

// NewRedisClientWithLimits creates a Redis client with separate idle and active connection limits.
func NewRedisClientWithLimits(addr string, poolSize int, maxActive int) (*RedisClient, error) {
	if poolSize <= 0 {
		poolSize = 1
	}
	if maxActive < poolSize {
		maxActive = poolSize
	}
	c := &RedisClient{
		addr:   addr,
		pool:   make(chan net.Conn, poolSize),
		active: make(chan struct{}, maxActive),
	}

	// Warm up some connections gracefully
	var connectedCount int
	for i := 0; i < poolSize; i++ {
		conn, err := c.dial("tcp", addr, 1*time.Second)
		if err == nil {
			c.pool <- conn
			connectedCount++
		}
	}

	if connectedCount == 0 {
		return nil, fmt.Errorf("redis server is unreachable at %s", addr)
	}
	return c, nil
}

func intEnv(key string, fallback int) int {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value <= 0 {
		return fallback
	}
	return value
}

func (c *RedisClient) dial(network, addr string, timeout time.Duration) (net.Conn, error) {
	if c != nil && c.DialFn != nil {
		return c.DialFn(network, addr)
	}
	return net.DialTimeout(network, addr, timeout)
}

func (c *RedisClient) dialContext(ctx context.Context, network, addr string) (net.Conn, error) {
	if c != nil && c.DialFn != nil {
		return c.DialFn(network, addr)
	}
	var d net.Dialer
	return d.DialContext(ctx, network, addr)
}

// NewMockRedisClient initializes a RedisClient with a custom DialFn for unit tests.
func NewMockRedisClient(dialFn func(network, addr string) (net.Conn, error)) *RedisClient {
	c := &RedisClient{
		addr:   "mock",
		pool:   make(chan net.Conn, 5),
		active: make(chan struct{}, 10),
		DialFn: dialFn,
	}
	conn, err := dialFn("tcp", "mock")
	if err == nil {
		c.pool <- conn
	}
	return c
}

func (c *RedisClient) isBroken() bool {
	if c == nil {
		return true
	}
	c.mu.RLock()
	defer c.mu.RUnlock()
	return time.Now().Before(c.brokenUntil)
}

func (c *RedisClient) recordSuccess() {
	if c == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.consecutiveFailures = 0
}

func (c *RedisClient) recordFailure() {
	if c == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.consecutiveFailures++
	if c.consecutiveFailures >= 5 {
		c.brokenUntil = time.Now().Add(15 * time.Second)
		log.Printf("Redis circuit breaker tripped! Disabling Redis requests for 15 seconds.")
	}
}

func (c *RedisClient) getConn(ctx context.Context) (net.Conn, error) {
	if c == nil {
		return nil, errors.New("redis client not initialized")
	}
	if c.isBroken() {
		return nil, errors.New("redis circuit breaker is tripped")
	}
	if err := c.acquireActive(ctx); err != nil {
		return nil, err
	}

	select {
	case conn := <-c.pool:
		// Verify connection is still alive using a non-blocking read
		_ = conn.SetReadDeadline(time.Now().Add(1 * time.Millisecond))
		one := make([]byte, 1)
		_, err := conn.Read(one)
		if err != nil && err != io.EOF && !isTimeout(err) {
			conn.Close() // Dead connection, replace it
			dialCtx, cancel := context.WithTimeout(ctx, 150*time.Millisecond)
			defer cancel()
			conn, err = c.dialContext(dialCtx, "tcp", c.addr)
			if err != nil {
				c.recordFailure()
				c.releaseActive()
				return nil, err
			}
			c.recordSuccess()
			return conn, nil
		}
		// Reset read deadline
		_ = conn.SetReadDeadline(time.Time{})
		return conn, nil
	default:
		// Pool is empty, instantiate a new connection with brief dial timeout
		dialCtx, cancel := context.WithTimeout(ctx, 150*time.Millisecond)
		defer cancel()
		conn, err := c.dialContext(dialCtx, "tcp", c.addr)
		if err != nil {
			c.recordFailure()
			c.releaseActive()
			return nil, err
		}
		c.recordSuccess()
		return conn, nil
	}
}

func (c *RedisClient) acquireActive(ctx context.Context) error {
	if c.active == nil {
		return nil
	}
	select {
	case c.active <- struct{}{}:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(100 * time.Millisecond):
		return errors.New("redis active connection limit reached")
	}
}

func (c *RedisClient) releaseActive() {
	if c.active == nil {
		return
	}
	select {
	case <-c.active:
	default:
	}
}

func isTimeout(err error) bool {
	if netErr, ok := err.(net.Error); ok {
		return netErr.Timeout()
	}
	return false
}

func (c *RedisClient) putConn(conn net.Conn, discard bool) {
	if c == nil {
		if conn != nil {
			conn.Close()
		}
		return
	}
	defer c.releaseActive()
	if discard || conn == nil {
		if conn != nil {
			conn.Close()
		}
		return
	}
	select {
	case c.pool <- conn:
	default:
		conn.Close() // Pool is full, discard connection
	}
}

// execute formats and writes a RESP command, then reads and parses the response.
func (c *RedisClient) execute(ctx context.Context, args ...string) (any, error) {
	conn, err := c.getConn(ctx)
	if err != nil {
		return nil, err
	}

	// Protect commands with read/write deadlines
	_ = conn.SetDeadline(time.Now().Add(1 * time.Second))

	_, err = conn.Write(serializeCommand(args...))
	if err != nil {
		c.putConn(conn, true)
		c.recordFailure()
		return nil, err
	}

	reader := &respReader{bufio.NewReader(conn)}
	res, err := reader.readResponse()
	if err != nil {
		c.putConn(conn, true)
		c.recordFailure()
		return nil, err
	}

	_ = conn.SetDeadline(time.Time{}) // Reset deadlines
	c.putConn(conn, false)
	c.recordSuccess()
	return res, nil
}

// Get executes standard REDIS GET command.
func (c *RedisClient) Get(ctx context.Context, key string) (string, error) {
	if c == nil {
		return "", errors.New("redis client not initialized")
	}
	res, err := c.execute(ctx, "GET", key)
	if err != nil {
		return "", err
	}
	if res == nil {
		return "", ErrNil
	}
	str, ok := res.(string)
	if !ok {
		return "", fmt.Errorf("unexpected value type: %T", res)
	}
	return str, nil
}

// Set executes standard REDIS SET command.
func (c *RedisClient) Set(ctx context.Context, key string, value string, expiration time.Duration) error {
	if c == nil {
		return errors.New("redis client not initialized")
	}
	var err error
	if expiration > 0 {
		seconds := strconv.Itoa(int(expiration.Seconds()))
		_, err = c.execute(ctx, "SET", key, value, "EX", seconds)
	} else {
		_, err = c.execute(ctx, "SET", key, value)
	}
	return err
}

// SetNX executes Redis SET key value NX with optional expiration.
func (c *RedisClient) SetNX(ctx context.Context, key string, value string, expiration time.Duration) (bool, error) {
	if c == nil {
		return false, errors.New("redis client not initialized")
	}
	args := []string{"SET", key, value, "NX"}
	if expiration > 0 {
		args = append(args, "EX", strconv.Itoa(int(expiration.Seconds())))
	}
	res, err := c.execute(ctx, args...)
	if err != nil {
		return false, err
	}
	if res == nil {
		return false, nil
	}
	str, ok := res.(string)
	if !ok {
		return false, fmt.Errorf("unexpected value type: %T", res)
	}
	return str == "OK", nil
}

// Del executes standard REDIS DEL command.
func (c *RedisClient) Del(ctx context.Context, key string) error {
	if c == nil {
		return errors.New("redis client not initialized")
	}
	_, err := c.execute(ctx, "DEL", key)
	return err
}

// DelPattern deletes all keys matching the given pattern using SCAN and DEL.
func (c *RedisClient) DelPattern(ctx context.Context, pattern string) error {
	if c == nil {
		return errors.New("redis client not initialized")
	}

	cursor := "0"
	for {
		res, err := c.execute(ctx, "SCAN", cursor, "MATCH", pattern, "COUNT", "100")
		if err != nil {
			return err
		}
		arr, ok := res.([]any)
		if !ok || len(arr) < 2 {
			return fmt.Errorf("unexpected SCAN result format: %T", res)
		}

		nextCursor, ok1 := arr[0].(string)
		keysArr, ok2 := arr[1].([]any)
		if !ok1 || !ok2 {
			return fmt.Errorf("unexpected SCAN elements types: cursor=%T, keys=%T", arr[0], arr[1])
		}

		// Delete the batch of keys found
		if len(keysArr) > 0 {
			delArgs := make([]string, 0, len(keysArr)+1)
			delArgs = append(delArgs, "DEL")
			for _, k := range keysArr {
				if keyStr, ok := k.(string); ok {
					delArgs = append(delArgs, keyStr)
				}
			}
			if len(delArgs) > 1 {
				_, err = c.execute(ctx, delArgs...)
				if err != nil {
					return err
				}
			}
		}

		cursor = nextCursor
		if cursor == "0" {
			break
		}
	}
	return nil
}

// Ping checks connectivity to the Redis server (PING).
func (c *RedisClient) Ping(ctx context.Context) (string, error) {
	if c == nil {
		return "", errors.New("redis client not initialized")
	}
	res, err := c.execute(ctx, "PING")
	if err != nil {
		return "", err
	}
	str, ok := res.(string)
	if !ok {
		return "", fmt.Errorf("unexpected value type: %T", res)
	}
	return str, nil
}

// Incr executes standard REDIS INCR command.
func (c *RedisClient) Incr(ctx context.Context, key string) (int64, error) {
	if c == nil {
		return 0, errors.New("redis client not initialized")
	}
	res, err := c.execute(ctx, "INCR", key)
	if err != nil {
		return 0, err
	}
	val, ok := res.(int64)
	if !ok {
		return 0, fmt.Errorf("unexpected value type: %T", res)
	}
	return val, nil
}

// serializeCommand serializes arguments into RESP array format.
func serializeCommand(args ...string) []byte {
	var buf []byte
	buf = append(buf, '*')
	buf = append(buf, strconv.Itoa(len(args))...)
	buf = append(buf, "\r\n"...)
	for _, arg := range args {
		buf = append(buf, '$')
		buf = append(buf, strconv.Itoa(len(arg))...)
		buf = append(buf, "\r\n"...)
		buf = append(buf, arg...)
		buf = append(buf, "\r\n"...)
	}
	return buf
}

type respReader struct {
	*bufio.Reader
}

func (r *respReader) readResponse() (any, error) {
	line, err := r.ReadString('\n')
	if err != nil {
		return nil, err
	}
	if len(line) < 3 {
		return nil, fmt.Errorf("invalid resp line: %q", line)
	}
	line = line[:len(line)-2] // strip \r\n

	switch line[0] {
	case '+': // Simple String
		return line[1:], nil
	case '-': // Error
		return nil, errors.New(line[1:])
	case ':': // Integer
		return strconv.ParseInt(line[1:], 10, 64)
	case '$': // Bulk String
		length, err := strconv.Atoi(line[1:])
		if err != nil {
			return nil, err
		}
		if length == -1 {
			return nil, nil // Null bulk string (Nil)
		}
		buf := make([]byte, length+2) // +2 for trailing \r\n
		if _, err := io.ReadFull(r, buf); err != nil {
			return nil, err
		}
		return string(buf[:length]), nil
	case '*': // Array
		length, err := strconv.Atoi(line[1:])
		if err != nil {
			return nil, err
		}
		if length == -1 {
			return nil, nil
		}
		arr := make([]any, length)
		for i := 0; i < length; i++ {
			val, err := r.readResponse()
			if err != nil {
				return nil, err
			}
			arr[i] = val
		}
		return arr, nil
	default:
		return nil, fmt.Errorf("unknown resp type byte: %c", line[0])
	}
}
