// Health Check Endpoint - Go / net/http
//
// Add to your HTTP server:
//   http.HandleFunc("/health", HealthHandler)
//   http.HandleFunc("/health/ready", ReadinessHandler)
//
// Endpoints:
//   GET /health       - Basic liveness check
//   GET /health/ready - Readiness check with dependencies

package main

import (
	"encoding/json"
	"net/http"
	"runtime"
	"time"
)

var startTime = time.Now()

// HealthResponse represents basic health check response
type HealthResponse struct {
	Status    string  `json:"status"`
	Timestamp string  `json:"timestamp"`
	Uptime    float64 `json:"uptime"`
}

// CheckResult represents a single dependency check
type CheckResult struct {
	Status  string `json:"status"`
	Latency int64  `json:"latency,omitempty"`
	Used    string `json:"used,omitempty"`
	Total   string `json:"total,omitempty"`
}

// ReadinessResponse represents readiness check response
type ReadinessResponse struct {
	Status    string                 `json:"status"`
	Timestamp string                 `json:"timestamp"`
	Checks    map[string]CheckResult `json:"checks"`
	Error     string                 `json:"error,omitempty"`
}

// HealthHandler handles basic liveness probe
func HealthHandler(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Uptime:    time.Since(startTime).Seconds(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// ReadinessHandler handles readiness probe with dependency checks
func ReadinessHandler(w http.ResponseWriter, r *http.Request) {
	response := ReadinessResponse{
		Status:    "healthy",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Checks:    make(map[string]CheckResult),
	}

	// Database check (uncomment and adapt)
	// start := time.Now()
	// err := db.Ping()
	// if err != nil {
	//     response.Status = "unhealthy"
	//     response.Checks["database"] = CheckResult{Status: "unhealthy"}
	// } else {
	//     response.Checks["database"] = CheckResult{
	//         Status:  "healthy",
	//         Latency: time.Since(start).Milliseconds(),
	//     }
	// }

	// Redis check (uncomment and adapt)
	// start := time.Now()
	// _, err := redis.Ping(ctx).Result()
	// if err != nil {
	//     response.Status = "unhealthy"
	//     response.Checks["redis"] = CheckResult{Status: "unhealthy"}
	// } else {
	//     response.Checks["redis"] = CheckResult{
	//         Status:  "healthy",
	//         Latency: time.Since(start).Milliseconds(),
	//     }
	// }

	// Memory check
	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)
	allocMB := memStats.Alloc / 1024 / 1024
	sysMB := memStats.Sys / 1024 / 1024

	memStatus := "healthy"
	if float64(allocMB) > float64(sysMB)*0.9 {
		memStatus = "warning"
	}

	response.Checks["memory"] = CheckResult{
		Status: memStatus,
		Used:   formatMB(allocMB),
		Total:  formatMB(sysMB),
	}

	// Goroutine check
	numGoroutines := runtime.NumGoroutine()
	goroutineStatus := "healthy"
	if numGoroutines > 10000 {
		goroutineStatus = "warning"
	}
	response.Checks["goroutines"] = CheckResult{
		Status: goroutineStatus,
		Used:   formatInt(numGoroutines),
	}

	w.Header().Set("Content-Type", "application/json")
	if response.Status == "unhealthy" {
		w.WriteHeader(http.StatusServiceUnavailable)
	} else {
		w.WriteHeader(http.StatusOK)
	}
	json.NewEncoder(w).Encode(response)
}

func formatMB(mb uint64) string {
	return string(rune(mb)) + "MB"
}

func formatInt(n int) string {
	return string(rune(n))
}

// Standalone usage (for testing)
// go run health.go
func main() {
	http.HandleFunc("/health", HealthHandler)
	http.HandleFunc("/health/ready", ReadinessHandler)

	port := ":8080"
	println("Health check running on http://localhost" + port + "/health")
	http.ListenAndServe(port, nil)
}
