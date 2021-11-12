locals {
    name = "test"
}

provider "google" {
    project = var.project
    region = var.region
}

module "service_group" {
    source = "../../modules/group"
}

module "service_network" {
    source = "../../modules/simple_network"
    name = local.name
    allow_outbound_internet_access = false // the default
}


locals {
    hello_container_path = "us-docker.pkg.dev/terranetes-resources/examples/hello"
    hello_container_digest = chomp(file("../build/hello-digest.txt"))
}

module "external_service" {
    source = "../../modules/service"
    name = "external-${local.name}"
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
            container_path = local.hello_container_path
            container_digest = local.hello_container_digest
            args = [
                "-port 8080",
                "-msg external",
                "-downstream \"http://${module.internal_service.internal_service_name}\"",
            ]
            machine_type = "e2-standard-2"
            preemptible = true
        }
    }
}

module "internal_service" {
    source = "../../modules/service"
    name = "internal-${local.name}"
    network = module.service_network.network
    subnetwork = module.service_network.subnetwork
    service_to_container_ports = {
      "80" = "8080"
    }
    http_health_check_path = "/"
    http_health_check_port = "80"
    external = false
    
    min_replicas = 2
    versions = {
        "hello-app-v2" = {
            container_path = local.hello_container_path
            container_digest = local.hello_container_digest
            args = [
                "-port 8080",
                "-msg internal",
            ]
            machine_type = "e2-standard-2"
            preemptible = true
        }
    }
}
