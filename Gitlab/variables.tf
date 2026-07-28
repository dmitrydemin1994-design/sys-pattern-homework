variable "flow" {
  type    = string
  default = "24-01"
}

variable "cloud_id" {
  type    = string
  default = "b1gmr1epgche6m46ivdf"
}

variable "folder_id" {
  type    = string
  default = "b1gfu61oc15cb99nqmfe"
}

variable "test" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }
}
