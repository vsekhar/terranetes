package main

import (
	"context"
	"flag"
	"fmt"
	"html"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"cloud.google.com/go/compute/metadata"
)

var port = flag.Uint("port", 0, "http listen port")
var msg = flag.String("msg", "none", "message to print in responses")
var downstream = flag.String("downstream", "", "URL for downstream request")

func main() {
	flag.Parse()

	// On GCP, OS provides hostnames like: "3b1179335f6d"
	hostname, err := os.Hostname()
	if err != nil {
		panic(err)
	}

	// On GCP, metadata service provides hostnames like:
	//   "t8s-external-test-ctv7.northamerica-northeast2-b.c.fabula-8589.internal"
	gcpHostname, err := metadata.Hostname()
	if err != nil {
		panic(err)
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Path: %q\n", html.EscapeString(r.URL.Path))
		fmt.Fprintf(w, "Hostname (OS): %s\n", hostname)
		fmt.Fprintf(w, "Hostname (Cloud): %s\n", gcpHostname)
		fmt.Fprintf(w, "Message: %s\n", *msg)
		fmt.Fprintf(w, "Time: %d\n", time.Now().UnixNano())
		log.Printf("request: %q\n", html.EscapeString(r.URL.Path))

		if *downstream != "" {
			fmt.Fprintf(w, "Downstream: %s\n", *downstream)
			fmt.Fprintf(w, "Downstream response:\n")
			resp, err := http.Get(*downstream)
			if err != nil {
				log.Printf("error getting downstream: %s", err)
				w.WriteHeader(500)
			}
			body, err := ioutil.ReadAll(resp.Body)
			if err != nil {
				log.Printf("error reading body: %s", err)
				w.WriteHeader(500)
			}
			fmt.Fprintf(w, "%s", body)
		}
	})

	srv := &http.Server{
		Addr:    fmt.Sprintf(":%d", *port),
		Handler: http.DefaultServeMux,
	}
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("listen error: %v", err)
		}
	}()
	log.Print("server started")
	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)
	sig := <-done
	log.Printf("stopping server on signal: %s", sig)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("shutdown error: %v", err)
	}
	log.Printf("server gracefully shutdown")
}
