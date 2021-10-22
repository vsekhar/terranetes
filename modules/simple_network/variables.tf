variable "name" {
   type = string
}

variable "allow_outbound_internet_access" {
    type = bool
    default = false
    description = "Allow hosts to access the internet."
}