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
variable "registry_mirrors" {}

variable "cluster_node_image" {
  type    = string
  default = "ubuntu-20.04"
}

variable "k8s_version" {
  type    = string
  default = "1.20.4"
}

variable "k8s_version_label_key" {
  type    = string
  default = "k8s_version"
}

variable "cluster_label_key" {
  type    = string
  default = "k8s_cluster"
}

variable "role_label_key" {
  type    = string
  default = "k8s_role"
}

variable "role_label_control" {
  type    = string
  default = "control"
}

variable "role_label_worker" {
  type    = string
  default = "worker"
}

variable "initializer_label_key" {
  type    = string
  default = "k8s_initializer"
}

variable "initializer_label_value" {
  type    = string
  default = "1"
}

variable "status_label_key" {
  type    = string
  default = "k8s_status"
}

variable "status_label_up" {
  type    = string
  default = "up"
}