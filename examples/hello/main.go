package main

import (
	"flag"
	"fmt"
	"html"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"time"
)

var port = flag.Uint("port", 0, "http listen port")
var msg = flag.String("msg", "none", "message to print in responses")
var downstream = flag.String("downstream", "", "URL for downstream request")

func main() {
	flag.Parse()

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Path: %q\n", html.EscapeString(r.URL.Path))
		hostname, err := os.Hostname()
		if err != nil {
			fmt.Fprintf(w, "Error: %s\n", err)
			w.WriteHeader(500)
		}
		fmt.Fprintf(w, "Host: %s\n", hostname)
		fmt.Fprintf(w, "Message: %s\n", *msg)
		fmt.Fprintf(w, "Time: %d\n", time.Now().UnixNano())
		log.Printf("request: %q\n", html.EscapeString(r.URL.Path))

		if *downstream != "" {
			resp, err := http.Get(*downstream)
			if err != nil {
				log.Printf("error getting downstream: %s", err)
				w.WriteHeader(500)
			}
			fmt.Fprintf(w, "Downstream:\n")
			body, err := ioutil.ReadAll(resp.Body)
			if err != nil {
				log.Printf("error reading body: %s", err)
				w.WriteHeader(500)
			}
			fmt.Fprintf(w, "%s", body)
		}
	})

	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", *port), nil))
}
