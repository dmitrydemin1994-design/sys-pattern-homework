variable "yc_service_account_key_file" {
  description = "./authorized_key.json"
}

variable "yc_cloud_id" {
  description = "Cloud ID"
}

variable "yc_folder_id" {
  description = "Folder ID"
}

variable "yc_zone" {
  default     = "ru-central1-a"
  description = "Зона"
}

variable "ssh_user" {
  default     = "ubuntu"
  description = "Пользователь для SSH-подключения"
}

variable "ssh_private_key_path" {
  description = "/home/dmitry/.ssh/yandex_cloud_key.pub"
}
