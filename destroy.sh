#!/bin/sh

terraform destroy --auto-approve

/bin/rm ~/.ssh/cluster.key

grep -v local.vcn /etc/hosts | sudo tee /etc/hosts.tmp
sudo cp -p /etc/hosts.tmp /etc/hosts
