// Command smoketest verifies that every service is up by polling its health
// endpoints through the gateway. It is a black-box check — no DB, no Kafka —
// just "does each port answer?".
//
//	GATEWAY_URL   base URL of the nginx gateway (default http://localhost:8080)
//	WAIT_SECONDS  how long to keep retrying while services boot (default 90)
//
// Exit code 0 = all healthy, 1 = at least one service never came up.
package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"time"
)

// service is one thing we probe. Port is informational (the gateway strips the
// prefix and forwards to that container port) so the report is easy to read.
type service struct {
	name   string
	prefix string // path prefix on the gateway; "" = the gateway itself
	port   int
}

var services = []service{
	{"gateway", "", 8080},
	{"catalog", "/catalog", 8081},
	{"order", "/order", 8082},
	{"payment", "/payment", 8083},
	{"cart", "/cart", 8084},
	{"review", "/review", 8086},
	{"promotion", "/promotion", 8087},
	{"media", "/media", 8088},
}

func main() {
	base := env("GATEWAY_URL", "http://localhost:8080")
	wait := time.Duration(atoi(env("WAIT_SECONDS", "90"), 90)) * time.Second

	fmt.Printf("smoketest → %s  (waiting up to %s for services to boot)\n\n", base, wait)

	client := &http.Client{Timeout: 3 * time.Second}
	deadline := time.Now().Add(wait)

	failed := 0
	for _, s := range services {
		url := base + s.prefix + "/healthz"
		ok, detail := probe(client, url, deadline)
		status := "OK  ✅"
		if !ok {
			status = "FAIL ❌"
			failed++
		}
		fmt.Printf("  %-11s :%d  %-8s %s\n", s.name, s.port, status, detail)
	}

	fmt.Println()
	if failed > 0 {
		fmt.Printf("RESULT: %d/%d services healthy — %d FAILED\n", len(services)-failed, len(services), failed)
		os.Exit(1)
	}
	fmt.Printf("RESULT: all %d services healthy ✅\n", len(services))
}

// probe hits url, retrying until it gets HTTP 200 or the deadline passes.
func probe(c *http.Client, url string, deadline time.Time) (bool, string) {
	var last string
	for {
		resp, err := c.Get(url)
		if err != nil {
			last = err.Error()
		} else {
			body, _ := io.ReadAll(io.LimitReader(resp.Body, 200))
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return true, snippet(string(body))
			}
			last = fmt.Sprintf("HTTP %d %s", resp.StatusCode, snippet(string(body)))
		}
		if time.Now().After(deadline) {
			return false, last
		}
		time.Sleep(2 * time.Second)
	}
}

func snippet(s string) string {
	s = trimNewlines(s)
	if len(s) > 80 {
		return s[:80] + "…"
	}
	return s
}

func trimNewlines(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' || s[i] == '\r' {
			continue
		}
		out = append(out, s[i])
	}
	return string(out)
}

func env(k, def string) string {
	if v, ok := os.LookupEnv(k); ok && v != "" {
		return v
	}
	return def
}

func atoi(s string, def int) int {
	if n, err := strconv.Atoi(s); err == nil {
		return n
	}
	return def
}
