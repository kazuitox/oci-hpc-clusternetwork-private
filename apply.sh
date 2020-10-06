#!/bin/sh

terraform apply --auto-approve

ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no opc@`terraform output bastion` "cat ~/.ssh/cluster.key" > ~/.ssh/cluster.key
chmod 600 ~/.ssh/cluster.key
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no opc@`terraform output bastion` cat /etc/hosts | grep local.vcn | sudo tee -a /etc/hosts

terraform destroy -target=oci_core_instance.bastion --auto-approve
