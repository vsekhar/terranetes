resource "google_project_service" "project_services" {
    for_each = toset([
        "compute.googleapis.com",
        "endpoints.googleapis.com",
        "iam.googleapis.com",
        "pubsub.googleapis.com",
        // "servicecontrol.googleapis.com", # for cloud endpoints
        // "servicemanagement.googleapis.com", # for cloud endpoints
    ])

    service = each.key
    disable_on_destroy = false
}

// TODO: move notion of network here
// TODO: create traffic director, certificate CA, etc.
// TODO: create examples/hellogrpc that uses proxyless service mesh (maybe as an internal service to examples/hello?)
