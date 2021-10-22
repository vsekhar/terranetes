locals {
    name = "test"
}

provider "google" {
    project = var.project
    region = var.region
}

module "service_network" {
    source = "../../modules/simple_network"
    name = local.name
    allow_outbound_internet_access = false // the default
}

data "google_container_registry_image" "hello-app-v2" {
    project = "google-samples"
    name = "hello-app:2.0"
}

module "example_service" {
    source = "../../modules/service"
    name = local.name
    network = module.service_network.network
    subnetwork = module.service_network.subnetwork
    service_to_container_ports = {
        "80": "8080"
    }
    http_health_check_path = "/"
    http_health_check_port = "80"
    external = true
    min_replicas = 2

    versions = {
        "hello-app-v2" = {
            container_image = data.google_container_registry_image.hello-app-v2
            machine_type = "e2-standard-2"
            preemptible = true
        }
    }
}

// TODO: test an internal service.
