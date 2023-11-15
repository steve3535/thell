#!/bin/bash

#Download base image
echo "Download base image ..."
lxc image ls images:ubuntu/23.10/cloud architecture=x86_64 type=disk-kvm.img
lxc image copy images:ubuntu/23.10/cloud --vm local: --alias=u2310 

#Create a template
echo "Create a template"
lxc query /1.0/instances/u2310ctrd
if [ "$?" -eq 0 ];then
  echo "removing existing template ..."
  lxc delete -f u2310ctrd
fi

#lxc init u2310 u2310ctrd 

#CLOUD-INIT
echo "CLOUD-INIT ..."
lxc launch u2310 u2310ctrd --config=user.user-data="$(cat ./config-u2310ctrd.yaml)"

#Shutdown 
echo "Shutdown ..."
while ! lxc exec u2310ctrd -- true;do
  sleep 5
done
lxc exec u2310ctrd -- cloud-init status --wait
lxc stop u2310ctrd --timeout 5

#Resize disk
echo "Resize disk ..."
lxc config device override u2310ctrd root size=20GB

#Set limits
echo "Set limits ..."
lxc config set u2310ctrd limits.cpu=1
lxc config set u2310ctrd limits.memory=1GiB

echo "Starting ..."
lxc start u2310ctrd

while ! lxc exec u2310ctrd -- true;do
  sleep 5
done

#Copy over required scripts
echo "Copy over required scripts ..."
tar cf - scripts/ | lxc exec u2310ctrd -- tar Cxvf /opt -

#Install containerd and runc
echo "Install containerd and runc ..."
lxc exec u2310ctrd -- /opt/scripts/setup_cri.sh containerd
lxc exec u2310ctrd -- /opt/scripts/prereq.sh

#Install kubetools
echo "Install kubetools ..."
lxc exec u2310ctrd -- /opt/scripts/kubetools.sh

#Publish the image
echo "Publish the image ..."
lxc stop u2310ctrd --timeout 5
lxc publish u2310ctrd local: --alias u2310ctrd --force

