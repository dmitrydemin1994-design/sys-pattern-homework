variable "flow" {
  type    = string
}

variable "cloud_id" {
  type    = string
}
variable "folder_id" {
  type    = string
}

variable "test" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }
}
