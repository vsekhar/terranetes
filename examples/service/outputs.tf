output "external_service_self_link" {
    value = module.external_service.self_link
}

output "internal_service_self_link" {
    value = module.internal_service.self_link
}

output "internal_service_service_name" {
    value = module.internal_service.internal_service_name
}
