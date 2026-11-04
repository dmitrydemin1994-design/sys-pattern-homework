output "lb_public_ip" {
  value = one([for l in yandex_lb_network_load_balancer.lb.listener : one(l.external_address_spec[*].address)])
}

output "vm1_public_ip" {
  value = yandex_compute_instance.vm[0].network_interface[0].nat_ip_address
}

output "vm2_public_ip" {
  value = yandex_compute_instance.vm[1].network_interface[0].nat_ip_address
}

output "all_ips" {
  value = {
    load_balancer = one([for l in yandex_lb_network_load_balancer.lb.listener : one(l.external_address_spec[*].address)])
    vm1           = yandex_compute_instance.vm[0].network_interface[0].nat_ip_address
    vm2           = yandex_compute_instance.vm[1].network_interface[0].nat_ip_address
  }
}
