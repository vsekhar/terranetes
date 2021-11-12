resource "google_service_account" "service_accounts" {
    for_each = var.versions
    
    account_id = "t8s-${var.name}-${each.key}"
    display_name = "t8s-${var.name}-${each.key}"
}

locals {

    // Roles required by Terranetes on each version's service account 
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

    // Roles requested by the user for each version's service account 
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
