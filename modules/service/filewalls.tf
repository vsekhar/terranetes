resource "google_compute_firewall" "allow-external" {
    for_each = var.external ? {0: ""} : {} // dynamic resources need a key

    name = "t8s-${var.name}-allow-external"
    network = var.network
    allow {
        protocol = "tcp"
        ports = [for k, v in var.service_to_container_ports : k]
    }
}

resource "google_compute_firewall" "allow-internal" {
    for_each = var.external ? {} : {0: ""} // dynamic resources need a key

    name = "t8s-${var.name}-allow-internal"
    network = var.network
    source_ranges = [ "10.128.0.0/9" ]
    priority = 65534
    direction = "INGRESS"
    allow {
        protocol = "icmp"
    }
    allow {
        protocol = "udp"
        ports = [for k, v in var.service_to_container_ports : k]
    }
    allow {
        protocol = "tcp"
        ports = [for k, v in var.service_to_container_ports : k]
    }
}

resource "google_compute_firewall" "allow_health_checks" {
    name = "t8s-${var.name}-allow-health-checks"
    network = var.network

    // https://cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges
    source_ranges = [ "35.191.0.0/16", "130.211.0.0/22" ]
    direction = "INGRESS"
    allow {
        protocol = "tcp"
        ports = [var.http_health_check_port]
    }
}
