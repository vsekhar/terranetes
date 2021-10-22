locals {
    forwarding_rule = var.external ? google_compute_forwarding_rule.external_forwarding_rule[0] : google_compute_forwarding_rule.internal_forwarding_rule[0]
}

output "self_link" {
    value = "http://${local.forwarding_rule.ip_address}"
}

output "ip" {
    value = local.forwarding_rule.ip_address
}

output "service_name" {
    value = local.forwarding_rule.service_name
}

output "version_service_accounts" {
    value = google_service_account.service_accounts
}
