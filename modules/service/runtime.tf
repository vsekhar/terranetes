module "container_vm_template" {
    for_each = var.versions

    source = "../vm"
    t8s_service = var.name
    t8s_version = each.key
    container_path = each.value["container_path"]
    container_digest = each.value["container_digest"]
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

resource "google_compute_region_instance_group_manager" "rigm" {
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
    // TODO: is the below still needed for pubsub scaling?
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

resource "google_compute_health_check" "hc" {
    name = "t8s-${var.name}-http"
    http_health_check {
      port = var.http_health_check_port
      request_path = var.http_health_check_path
    }
}
