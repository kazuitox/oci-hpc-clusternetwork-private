data "oci_core_cluster_network_instances" "cluster_network_instances" {
  cluster_network_id = oci_core_cluster_network.cluster_network.id
  compartment_id     = var.compartment_ocid
}

data "oci_core_instance" "cluster_instances" {
  count       = var.node_count
  instance_id = data.oci_core_cluster_network_instances.cluster_network_instances.instances[count.index]["id"]
}

output "bastion" {
  value = oci_core_instance.bastion.private_ip
}

output "private_ips" {
  value = join(" ", data.oci_core_instance.cluster_instances.*.private_ip)
}

