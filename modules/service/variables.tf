terraform {
    experiments = [module_variable_optional_attrs]
}

variable "name" {
    type = string
}

variable "network" {
    type = string
}

variable "subnetwork" {
    type = string
}

variable "versions" {
    type = map(object({
        container_image = object({
            project = string
            name = string
            digest = string
            image_url = string
        })
        args = optional(list(string))
        env = optional(map(string))
        machine_type = string
        target_size = optional(object({
            fixed = optional(number)
            percent = optional(number)
        }))
        preemptible = optional(bool)
        service_account_roles = optional(list(string))
        # envoy_config = optional(object({
        #     service_name = string
        #     envoy_service_port = string
        #     backend_protocol = string
        #     backend_service_port = string
        # }))
    }))
    description = "Versions to run."
}

variable "service_to_container_ports" {
    type = map(string)
    default = {}
}

variable "external" {
    type = bool
    default = false
}

variable "http_health_check_path" {
    type = string
    description = "Relative path that returns 200 OK when healthy (e.g. '/healthz')."
}

variable "http_health_check_port" {
    type = number
    default = 8080
    description = "Service port on which to send HTTP health checks."
}

variable "min_replicas" {
    type = number
    default = 1
    description = "Minimum number of replicas per region."
}

variable "max_replicas" {
    type = number
    default = 10
}
