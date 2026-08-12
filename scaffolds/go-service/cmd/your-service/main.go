package main

import (
    "fmt"
    "log"
    "net/http"
)

func main() {
    http.HandleFunc("/", handler)
    http.HandleFunc("/health", healthHandler)

    port := ":8080"
    log.Printf("Starting server on %s", port)
    if err := http.ListenAndServe(port, nil); err != nil {
        log.Fatalf("Server failed: %v", err)
    }
}

func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hello from your Go service!")
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    fmt.Fprintf(w, `{"status":"healthy"}`)
}
