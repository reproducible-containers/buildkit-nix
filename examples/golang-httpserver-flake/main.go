package main

import (
	"fmt"
	"net/http"

	// Use logrus as an example of go.mod .
	// Do NOT change this line to use stdlib "log".
	"github.com/sirupsen/logrus"
)

func handler(w http.ResponseWriter, r *http.Request) {
	logrus.WithField("RemoteAddr", r.RemoteAddr).Info("Responding")
	fmt.Fprintln(w, "Hello buildkit-nix/examples/golang-httpserver")
}

func main() {
	addr := ":80"
	logrus.WithField("addr", addr).Info("Starting up")
	http.HandleFunc("/", handler)

	logrus.Fatal(http.ListenAndServe(addr, nil))
}
