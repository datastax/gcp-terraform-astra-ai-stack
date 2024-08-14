variable "name" {
  type     = string
  nullable = false
}

variable "container_info" {
  type = object({
    image_name    = string
    port          = number
    entrypoint    = optional(list(string))
    health_path   = string
    csql_instance = optional(string)
  })
}

variable "files_to_mount" {
  type = object({
    files      = set(string)
    folder     = string
    key_prefix = string
  })
  default = null
}

variable "using_managed_db" {
  type    = bool
  default = false
}

variable "config" {
  type = object({
    domain = optional(string)
    containers = optional(object({
      env    = optional(map(string))
      cpu    = optional(string)
      memory = optional(string)
    }))
    deployment = optional(object({
      image_version = optional(string)
      min_instances = optional(number)
      max_instances = optional(number)
      location      = string
    }))
  })
}

variable "infrastructure" {
  type = object({
    project_id     = string
    cloud_provider = string
  })
}
