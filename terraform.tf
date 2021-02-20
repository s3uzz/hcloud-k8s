provider "hcloud" {
  token = var.hcloud_token
}

variable "hcloud_token" {}
variable "cluster_authorized_ssh_keys" {}
variable "cluster_name" {}
variable "cluster_controlnode_count" {}
variable "cluster_controlnode_types" {}
variable "cluster_controlnode_locations" {}
variable "cluster_workernode_count" {}
variable "cluster_workernode_types" {}
variable "cluster_workernode_locations" {}
variable "cluster_network_zone" {}
variable "cluster_network_ip_range" {}
variable "cluster_network_ip_range_loadbalancer" {}
variable "cluster_network_ip_range_controlnode" {}
variable "cluster_network_ip_range_workernode" {}
variable "cluster_network_ip_range_service" {}
variable "cluster_network_ip_range_pod" {}
variable "cluster_controllb_type" {}
variable "cluster_controllb_location" {}
variable "cluster_controllb_listen_port" {}
variable "cluster_workerlb_type" {}
variable "cluster_workerlb_location" {}
variable "cluster_ingress" {}
variable "cluster_cni" {}

variable "cluster_node_image" {
  type    = string
  default = "ubuntu-20.04"
}

variable "cluster_label_key" {
  type    = string
  default = "k8s_cluster"
}

variable "cluster_node_role_label_key" {
  type    = string
  default = "k8s_cluster_role"
}

resource "hcloud_network" "network" {
  name     = var.cluster_name
  ip_range = var.cluster_network_ip_range
  labels = {
    (var.cluster_label_key) : var.cluster_name,
  }
}

resource "hcloud_network_subnet" "network_subnet_loadbalancer" {
  type         = "cloud"
  network_id   = hcloud_network.network.id
  network_zone = var.cluster_network_zone
  ip_range     = var.cluster_network_ip_range_loadbalancer
}

resource "hcloud_network_subnet" "network_subnet_controlnode" {
  type         = "cloud"
  network_id   = hcloud_network.network.id
  network_zone = var.cluster_network_zone
  ip_range     = var.cluster_network_ip_range_controlnode
}

resource "hcloud_network_subnet" "network_subnet_workernode" {
  type         = "cloud"
  network_id   = hcloud_network.network.id
  network_zone = var.cluster_network_zone
  ip_range     = var.cluster_network_ip_range_workernode
}

resource "hcloud_server" "controlnode" {
  count       = var.cluster_controlnode_count
  name        = "${var.cluster_name}-controlnode-${count.index + 1}"
  image       = var.cluster_node_image
  server_type = split(",", var.cluster_controlnode_types)[count.index]
  location    = split(",", var.cluster_controlnode_locations)[count.index]
  ssh_keys    = split(",", var.cluster_authorized_ssh_keys)
  labels = {
    (var.cluster_label_key) : var.cluster_name,
    (var.cluster_node_role_label_key) : "control",
  }

  connection {
    type = "ssh"
    user = "root"
    host = self.ipv4_address
  }

  provisioner "remote-exec" {
    inline = [
      # Use Hetzner mirror instead of the official mirrors (faster downloads)
      "echo > /etc/apt/sources.list",
    ]
  }
}

resource "hcloud_server" "workernode" {
  count       = var.cluster_workernode_count
  name        = "${var.cluster_name}-workernode-${count.index + 1}"
  image       = var.cluster_node_image
  server_type = split(",", var.cluster_workernode_types)[count.index]
  location    = split(",", var.cluster_workernode_locations)[count.index]
  ssh_keys    = split(",", var.cluster_authorized_ssh_keys)
  labels = {
    (var.cluster_label_key) : var.cluster_name,
    (var.cluster_node_role_label_key) : "worker",
  }

  connection {
    type = "ssh"
    user = "root"
    host = self.ipv4_address
  }

  provisioner "remote-exec" {
    inline = [
      # Use Hetzner mirror instead of the official mirrors (faster downloads)
      "echo > /etc/apt/sources.list",
    ]
  }
}

resource "hcloud_server_network" "controlnode_network" {
  count      = var.cluster_controlnode_count
  server_id  = hcloud_server.controlnode[count.index].id
  network_id = hcloud_network.network.id
  ip         = cidrhost(var.cluster_network_ip_range_controlnode, count.index + 1)
}

resource "hcloud_server_network" "workernode_network" {
  count      = var.cluster_workernode_count
  server_id  = hcloud_server.workernode[count.index].id
  network_id = hcloud_network.network.id
  ip         = cidrhost(var.cluster_network_ip_range_workernode, count.index + 1)
}

resource "hcloud_load_balancer" "controllb" {
  name               = "${var.cluster_name}-control"
  load_balancer_type = var.cluster_controllb_type
  location           = var.cluster_controllb_location
  labels = {
    (var.cluster_label_key) : var.cluster_name,
    (var.cluster_node_role_label_key) : "control",
  }

  algorithm {
    type = "least_connections"
  }
}

resource "hcloud_load_balancer_network" "controllb_network" {
  load_balancer_id = hcloud_load_balancer.controllb.id
  network_id       = hcloud_network.network.id
  ip               = cidrhost(var.cluster_network_ip_range_loadbalancer, 1)
}

resource "hcloud_load_balancer_target" "controllb_target" {
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.controllb.id
  label_selector   = "${var.cluster_label_key}=${var.cluster_name},${var.cluster_node_role_label_key}=control"
  use_private_ip   = true

  depends_on = [
    hcloud_load_balancer_network.controllb_network
  ]
}

resource "hcloud_load_balancer_service" "controllb_service_https" {
  load_balancer_id = hcloud_load_balancer.controllb.id
  protocol         = "tcp"
  listen_port      = var.cluster_controllb_listen_port
  destination_port = 6443

  health_check {
    protocol = "http"
    port     = 6443
    interval = 10
    timeout  = 5
    retries  = 3
    http {
      tls          = true
      path         = "/readyz"
      response     = "ok"
      status_codes = ["200"]
    }
  }
}

resource "hcloud_load_balancer" "workerlb" {
  name               = "${var.cluster_name}-worker"
  load_balancer_type = var.cluster_workerlb_type
  location           = var.cluster_workerlb_location
  labels = {
    (var.cluster_label_key) : var.cluster_name,
    (var.cluster_node_role_label_key) : "worker",
  }

  algorithm {
    type = "least_connections"
  }
}

resource "hcloud_load_balancer_network" "workerlb_network" {
  load_balancer_id = hcloud_load_balancer.workerlb.id
  network_id       = hcloud_network.network.id
  ip               = cidrhost(var.cluster_network_ip_range_loadbalancer, 2)
}

resource "hcloud_load_balancer_target" "workerlb_target" {
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.workerlb.id
  label_selector   = "${var.cluster_label_key}=${var.cluster_name},${var.cluster_node_role_label_key}=worker"
  use_private_ip   = true

  depends_on = [
    hcloud_load_balancer_network.workerlb_network
  ]
}

resource "hcloud_load_balancer_service" "workerlb_service_http" {
  load_balancer_id = hcloud_load_balancer.workerlb.id
  protocol         = "tcp"
  listen_port      = 80
  destination_port = 80
  proxyprotocol    = true

  health_check {
    protocol = "tcp"
    port     = 80
    interval = 10
    timeout  = 5
    retries  = 3
  }
}

resource "hcloud_load_balancer_service" "workerlb_service_https" {
  load_balancer_id = hcloud_load_balancer.workerlb.id
  protocol         = "tcp"
  listen_port      = 443
  destination_port = 443
  proxyprotocol    = true

  health_check {
    protocol = "tcp"
    port     = 443
    interval = 10
    timeout  = 5
    retries  = 3
  }
}

output "hcloud_token" {
  value     = var.hcloud_token
  sensitive = true
}

output "cluster_name" {
  value = var.cluster_name
}

output "controlnode_names" {
  value = hcloud_server.controlnode.*.name
}

output "workernode_names" {
  value = hcloud_server.workernode.*.name
}

output "controlnode_ipv4_addresses" {
  value = hcloud_server.controlnode.*.ipv4_address
}

output "workernode_ipv4_addresses" {
  value = hcloud_server.workernode.*.ipv4_address
}

output "cluster_network_ip_range_service" {
  value = var.cluster_network_ip_range_service
}

output "cluster_network_ip_range_pod" {
  value = var.cluster_network_ip_range_pod
}

output "controllb_ipv4_address" {
  value = hcloud_load_balancer.controllb.ipv4
}

output "controllb_k8s_endpoint" {
  value = "${hcloud_load_balancer.controllb.ipv4}:${hcloud_load_balancer_service.controllb_service_https.listen_port}"
}

output "controllb_private_k8s_endpoint" {
  value = "${hcloud_load_balancer_network.controllb_network.ip}:${hcloud_load_balancer_service.controllb_service_https.listen_port}"
}

output "cluster_ingress" {
  value = var.cluster_ingress
}

output "cluster_cni" {
  value = var.cluster_cni
}
