#!/bin/bash
set -e
set -x

#this is a basic script to make sure some initial conditions are met before a
# kubadm init/join

sudo setenforce 0
sudo swapoff -a
sudo kubeadm reset
#remove old conf
rm $HOME/.kube/config

