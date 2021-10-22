resource "google_compute_network" "network" {
    name = "t8s-${var.name}"
    auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
    name = "t8s-${var.name}"
    network = google_compute_network.network.self_link
    ip_cidr_range = "10.128.0.0/20"
    private_ip_google_access = true
}

resource "google_compute_firewall" "allow_ssh_from_iap" {
    // https://cloud.google.com/iap/docs/using-tcp-forwarding
    lifecycle {
      create_before_destroy = true
    }
    name = "t8s-${var.name}-allow-ssh-from-iap"
    network = google_compute_network.network.name
    source_ranges = ["35.235.240.0/20"]
    direction = "INGRESS"
    allow {
        protocol = "tcp"
        ports = ["22"]
    }
}

resource "google_compute_router" "router" {
    // Create if allow_outbound_internet_access == true
    count = var.allow_outbound_internet_access == true ? 1 : 0

    name = "t8s-${var.name}"
    network = google_compute_network.network.name
}

resource "google_compute_router_nat" "nat" {
    // Create if allow_outbound_internet_access == true
    count = var.allow_outbound_internet_access == true ? 1 : 0

    name = "t8s-${var.name}"
    router = google_compute_router.router[0].name
    nat_ip_allocate_option = "AUTO_ONLY"
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
