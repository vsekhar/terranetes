
resource "google_compute_region_health_check" "hc" {
    name = "t8s-${var.name}-http-regional"
    http_health_check {
      port = var.http_health_check_port
      request_path = var.http_health_check_path
    }
}

resource "google_compute_region_backend_service" "be" {
    name = "t8s-${var.name}"
    health_checks = [google_compute_region_health_check.hc.id]
    load_balancing_scheme = var.external ? "EXTERNAL" : "INTERNAL"
    backend {
      group = google_compute_region_instance_group_manager.rigm.instance_group
    }
    connection_draining_timeout_sec = 30
}

resource "google_compute_forwarding_rule" "external_forwarding_rule" {
    for_each = var.external ? {0: ""} : {} // dynamic resources need a key

    name = "t8s-${var.name}"
    backend_service = google_compute_region_backend_service.be.id

    ports = [for k, v in var.service_to_container_ports : k] // max 5 ports

    // Use port_range below if more than 5 ports are needed (and to avoid)
    // perpetual diffs).
    // port_range = "1-65535" 
}

resource "google_compute_forwarding_rule" "internal_forwarding_rule" {
    for_each = var.external ? {} : {0: ""} // dynamic resources need a key

    name = "t8s-${var.name}"
    network = var.network
    subnetwork = var.subnetwork
    backend_service = google_compute_region_backend_service.be.id
    load_balancing_scheme = "INTERNAL"

    ports = [for k, v in var.service_to_container_ports : k] // max 5 ports
    // all_ports = true // use if more than 5 ports are needed.

    // If service_label is not set, an internal DNS name is not created.
    service_label = "lb" // --> lb.t8s-groupname-servicename.il4.region.lb.projectID.internal
}

// TODO: use traffic director

// TODO: add SSL
