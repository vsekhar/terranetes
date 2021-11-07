variable "t8s_service" {
    type = string
}

variable "t8s_version" {
    type = string
}

// Configure the machine.

variable "network" {
    type = string
    default = null
}

variable "subnetwork" {
    type = string
    default = null
}

variable "public_ip" {
    type = string
    description = "Public IP to assign to the instance: '0.0.0.0' for ephemeral; '' for none (the default)"
    default = ""
}

variable "service_account" {
    type = string
    default = null
}

variable "preemptible" {
    type = bool
    default = false
}

variable "machine_type" {
    type = string
}

variable "tags" {
    type = list(string)
    default = []
}

// Configure the process.

variable "container_path" {
    type = string
}

variable "container_digest" {
    type = string
}

variable "args" {
    type = list(string)
    default = []
}

variable "env" {
    type = map(string)
    default = {}
}

variable "host_to_container_ports" {
    type = map(string)
    default = {}
}

// Configure the sidecar.

variable "envoy_config" {
    type = object({
        service_name = string
        envoy_service_port = string
        backend_protocol = string
        backend_service_port = string
    })
    default = null
    description = "If specified, envoy_config will deploy envoy V2 and have it forward requests from envoy_service_port to backend_service_port. The appropriate firewall settings and port forwarding will be automatically configured."
}
