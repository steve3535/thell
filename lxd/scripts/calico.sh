#!/bin/bash
mkdir -p /home/k8s/.kube
cp -i /etc/kubernetes/admin.conf /home/k8s/.kube/config
chown -R k8s:k8s /home/k8s/.kube

kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://docs.projectcalico.org/manifests/calico.yaml 

