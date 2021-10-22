resource "google_project_service" "project_services" {
    // TODO: move this into t8s?
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

resource "google_service_account" "service_accounts" {
    for_each = var.versions
    
    account_id = "t8s-${var.name}-${each.key}"
    display_name = "t8s-${var.name}-${each.key}"
}

locals {
    t8s_roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/cloudtrace.agent",
        "roles/servicemanagement.serviceController",
    ]
    t8s_sa_roles = flatten([
        for k, v in var.versions: [
            for r in local.t8s_roles: {
                role = r 
                service_account = google_service_account.service_accounts[k].email
            }
        ]
    ])

    custom_sa_roles = flatten([
        for k, v in var.versions: [
            for r in v.service_account_roles != null ? v.service_account_roles : []: {
                role = r
                service_account = google_service_account.service_accounts[k].email
            }
        ]
    ])
}

resource "google_project_iam_member" "iam_t8s" {
    for_each = { for e in local.t8s_sa_roles: e.role => e.service_account }

    role = each.key
    member = "serviceAccount:${each.value}"
}

resource "google_project_iam_member" "iam_custom" {
    for_each = { for e in local.custom_sa_roles: e.role => e.service_account }

    role = each.key
    member = "serviceAccount:${each.value}"
}
module "container_vm_template" {
    for_each = var.versions

    source = "../vm"
    name = "${var.name}-${each.key}"
    container_image = each.value["container_image"]
    args = each.value["args"]
    env = each.value["env"]
    host_to_container_ports = var.service_to_container_ports
    // envoy_config = each.value["envoy_config"]
    preemptible = each.value["preemptible"]
    machine_type = each.value["machine_type"]
    network = var.network
    subnetwork = try(var.subnetwork, null)
    service_account = google_service_account.service_accounts[each.key].email
}

// forwarding rule (int/ext) --> be service (int/ext) --> rigm (common) --> firewall (int/ext) -- > instances (common)
//                                \ region health check   |- autoscaler (common)
//                                  (common)               \ global health check (common)

data "google_client_config" "current" {}

resource "google_compute_region_instance_group_manager" "rigm" {
    // these seem to be required for this resource...
    // project = data.google_client_config.current.project
    // region = data.google_client_config.current.region

    name = "t8s-${var.name}"
    base_instance_name = "t8s-${var.name}"
    auto_healing_policies {
        health_check = google_compute_health_check.hc.id
        initial_delay_sec = 300 // 5 mins
    }
    dynamic "version" {
        for_each = var.versions
        content {
            name = version.key
            instance_template = module.container_vm_template[version.key].self_link
            dynamic "target_size" {
                for_each = version.value["target_size"] != null ? [1] : []
                content {
                    fixed = version.value["target_size"].fixed
                    percent = version.value["target_size"].percent
                }
            }
        }
    }
}

resource "google_compute_region_autoscaler" "autoscaler" {
    // these seem to be required for this resource...
    // project = data.google_client_config.current.project
    // region = data.google_client_config.current.region

    // TODO: is the below still needed?
    // provider = google-beta // for filter and single_instance_assignment

    name = "t8s-${var.name}"
    target = google_compute_region_instance_group_manager.rigm.id
    autoscaling_policy {
        mode = "ON"
        max_replicas = var.max_replicas
        min_replicas = var.min_replicas
        cooldown_period = 120
        cpu_utilization {
            target = 0.5
        }

        // https://cloud.google.com/compute/docs/autoscaler/scaling-stackdriver-monitoring-metrics#example_using_instance_assignment_to_scale_based_on_a_queue
        # dynamic "metric" {
        #     for_each = var.pubsub_autoscale != null ? [1] : []
        #     content {
        #         name = "pubsub.googleapis.com/subscription/num_undelivered_messages"
        #         type = "GAUGE"
        #         filter = "resource.type = pubsub_subscription AND resource.label.subscription_id = ${var.pubsub_autoscale.subscription}"
        #         single_instance_assignment = var.pubsub_autoscale.single_instance_assignment
        #     }
        # }
    }
}

resource "google_compute_region_health_check" "hc" {
    name = "t8s-${var.name}-http-regional"
    http_health_check {
      port = var.http_health_check_port
      request_path = var.http_health_check_path
    }
}

resource "google_compute_health_check" "hc" {
    name = "t8s-${var.name}-http"
    http_health_check {
      port = var.http_health_check_port
      request_path = var.http_health_check_path
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

resource "google_compute_region_backend_service" "be" {
    name = "svc-${var.name}"
    health_checks = [google_compute_region_health_check.hc.id]
    load_balancing_scheme = var.external ? "EXTERNAL" : "INTERNAL"
    backend {
      group = google_compute_region_instance_group_manager.rigm.instance_group
    }
}

resource "google_compute_forwarding_rule" "external_forwarding_rule" {
    for_each = var.external ? {0: ""} : {} // dynamic resources need a key

    name = "svc-${var.name}"
    backend_service = google_compute_region_backend_service.be.id
    port_range = "1-65535" // prevent perpetual diffs which force replacement
}

resource "google_compute_forwarding_rule" "internal_forwarding_rule" {
    for_each = var.external ? {} : {0: ""} // dynamic resources need a key

    name = "svc-${var.name}"
    network = var.network
    subnetwork = var.subnetwork
    backend_service = google_compute_region_backend_service.be.id
    load_balancing_scheme = "INTERNAL"
    all_ports = true
    service_label = "lb" // --> lb.svc-groupname-servicename.il4.region.lb.projectID.internal
}

resource "google_compute_firewall" "allow-external" {
    for_each = var.external ? {0: ""} : {} // dynamic resources need a key

    name = "svc-${var.name}-allow-external"
    network = var.network
    allow {
        protocol = "tcp"
        ports = [for k, v in var.service_to_container_ports : k]
    }
}

resource "google_compute_firewall" "allow-internal" {
    for_each = var.external ? {} : {0: ""} // dynamic resources need a key

    name = "svc-${var.name}-allow-internal"
    network = var.network

    // copied from default-allow-internal
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
