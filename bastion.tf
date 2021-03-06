locals {
  bastion_subnet_id = var.use_existing_vcn ? var.bastion_subnet_id : var.private_subnet
}

data "template_file" "bastion_config" {
  template = file("config.bastion")
  vars = {
    key = tls_private_key.ssh.private_key_pem
  }
}

resource "oci_core_instance" "bastion" {
  depends_on          = [oci_core_cluster_network.cluster_network]
  availability_domain = var.bastion_ad
  compartment_id      = var.compartment_ocid
  shape               = var.bastion_shape
  display_name        = "${local.cluster_name}-bastion"
  metadata = {
    ssh_authorized_keys = "${var.ssh_key}\n${tls_private_key.ssh.public_key_openssh}"
    user_data           = base64encode(data.template_file.bastion_config.rendered)
  }
  source_details {
    source_id   = var.use_standard_image ? var.bastion_image[var.region] : var.custom_bastion_image
    source_type = "image"
  }
  create_vnic_details {
    subnet_id = local.bastion_subnet_id
    assign_public_ip = false
  }


  provisioner "file" {
    source        = "playbooks"
    destination   = "/home/opc/"
    connection {
      host        = oci_core_instance.bastion.private_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content        = templatefile("${path.module}/inventory.tpl", {  
      bastion_name = oci_core_instance.bastion.display_name, 
      bastion_ip = oci_core_instance.bastion.private_ip, 
      compute = zipmap(data.oci_core_instance.cluster_instances.*.display_name, 
      data.oci_core_instance.cluster_instances.*.private_ip), 
      rdma_network = var.rdma_network,
      private_subnet = var.private_subnet
      nfs = data.oci_core_cluster_network_instances.cluster_network_instances.instances[0]["display_name"],
      scheduler = var.scheduler,
      configure_nfs = var.configure_nfs,
      nfs_mount_path = var.nfs_mount_path,
      intel_mpi_version = var.intel_mpi_version, 
      intel_mpi = var.intel_mpi
      })

    destination   = "/home/opc/playbooks/inventory"
    connection {
      host        = oci_core_instance.bastion.private_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/cluster.key"
    connection {
      host        = oci_core_instance.bastion.private_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/id_rsa"
    connection {
      host        = oci_core_instance.bastion.private_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content     = join("\n", data.oci_core_instance.cluster_instances.*.private_ip)
    destination = "/tmp/hosts"
    connection {
      host        = oci_core_instance.bastion.private_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    source      = "configure.sh"
    destination = "/tmp/configure.sh"
    connection {
      host        = oci_core_instance.bastion.private_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/opc/.ssh/cluster.key",
      "chmod 600 /home/opc/.ssh/id_rsa",
      "chmod a+x /tmp/configure.sh",
      "/tmp/configure.sh"
    ]
    connection {
      host        = oci_core_instance.bastion.private_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }
}

