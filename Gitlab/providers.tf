terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.129.0"
    }
  }

  required_version = ">=1.8.4"
}

provider "yandex" {
  # token                    = "do not use!!!"
  cloud_id                 = "b1gmr1epgche6m46ivdf"
  folder_id                = "b1gs15mnfvf0t03reo5a"
  service_account_key_file = "authorized_key.json"
}
