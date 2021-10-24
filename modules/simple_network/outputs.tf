output "network" {
    value = google_compute_network.network.name
}

output "subnetwork" {
    value = google_compute_subnetwork.subnetwork.name
}
