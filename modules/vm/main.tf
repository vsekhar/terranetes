locals {
    name = "${var.t8s_service}-${var.t8s_version}"
}

data "google_compute_image" "cos" {
    // https://cloud.google.com/container-optimized-os/docs/release-notes
    family = "cos-93-lts"
    project = "cos-cloud"
}

resource "google_compute_instance_template" "template" {
    lifecycle {
        create_before_destroy = true
    }

    name_prefix = "t8s-${local.name}-"
    tags = length(var.tags) > 0 ? var.tags : null
    labels = {
        // labels must be [a-z0-9_-] and at most 63 characters
        t8s-service = var.t8s_service
        t8s-service-version = "${var.t8s_service}-${var.t8s_version}"
        container-vm = data.google_compute_image.cos.name
        container-registry = replace(split("/", var.container_path)[0], "/[:.]/", "_")
        container-project = split("/", var.container_path)[1]
        container-repo = split("/", var.container_path)[2]
        container-name = split("/", var.container_path)[3]
        container-digest-prefix = substr(replace(var.container_digest, "/[:]/", "_"), 0, 15)
    }
    machine_type = var.machine_type
    disk {
        source_image = data.google_compute_image.cos.self_link
        auto_delete = true
        boot = true
    }

    metadata = {
        user-data = templatefile("${path.module}/gce_cloud-init.tmpl.yaml",
            {
                service_name = local.name
                container_image_name = join("@", [var.container_path, var.container_digest])
                registry = split("/", var.container_path)[0]
                host_to_container_ports = var.host_to_container_ports
                args = var.args != null ? var.args : []
                env = var.env != null ? var.env : {}
                envoy_config = var.envoy_config
            }
        )
        google-logging-enabled = "true"
        google-monitoring-enabled = "true"
        cos-metrics-enabled = "true"
        enable-oslogin = "true"
    }

    network_interface {
        network = (var.network == null && var.subnetwork == null) ? "default" : var.network
        subnetwork = var.subnetwork

        dynamic "access_config" {
            for_each = var.public_ip == "" ? [] : [1]
            content {
                network_tier = "PREMIUM"
                nat_ip = (var.public_ip != "0.0.0.0" ? var.public_ip : null)
            }
        }
    }

    scheduling {
        preemptible         = var.preemptible
        on_host_maintenance = "TERMINATE" // required for preemptible
        automatic_restart   = "false"     // required for preemptible
    }

    dynamic "service_account" {
        for_each = var.service_account != null ? [1] : []
        content {
            email = var.service_account
            scopes = [
                // Restrict via IAM on service account:
                // https://cloud.google.com/compute/docs/access/service-accounts#service_account_permissions
                "https://www.googleapis.com/auth/cloud-platform",
            ]
        }
    }

    shielded_instance_config {
      enable_secure_boot = true
      enable_vtpm = true
      enable_integrity_monitoring = true
    }
}
