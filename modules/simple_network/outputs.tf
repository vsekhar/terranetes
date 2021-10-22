output "network" {
    value = google_compute_network.network.id
}

output "subnetwork" {
    value = google_compute_subnetwork.subnetwork.id
}
