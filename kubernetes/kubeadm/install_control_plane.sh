#!/bin/bash

cri=""
node="control_plane"
pod_network="weaveworks"

install_containerd () {
  # clean up if necessary
  if test -f /etc/containerd/config.toml; then
    sudo rm /etc/containerd/config.toml
  else
    if ! test -d /etc/containerd/; then
      sudo mkdir -p /etc/containerd/
    fi
  fi

  if [ "$?" -ne "0" ]; then
      echo "containerd clean up prior to install failed... exiting...\n"
      exit 1
  fi

  # install and configure the config file
  sudo apt-get install -y containerd.io && \
  sudo containerd config default | sudo tee -a config.toml && \
  sed -i 's/pause:3.*/pause:3.9\"/' config.toml && \
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' config.toml && \
  chmod 0400 config.toml && \
  sudo chown root:root config.toml && \
  sudo mv config.toml /etc/containerd/ && \

  sudo systemctl restart containerd  
}

# this is not working yet
install_cri_o () {
  #target os
  export OS=xUbuntu_22.04
  export VERSION=1.24

  #echo 'deb http://deb.debian.org/debian buster-backports main' | sudo tee -a /etc/apt/sources.list.d/backports.list && \
  #sudo apt update && \
  #sudo apt install -y -t buster-backports libseccomp2 || sudo apt update -y -t buster-backports libseccomp2 && \

  echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | sudo tee -a /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list && \
  echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.24:/1.24.6/$OS/ /" | sudo tee -a /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list && \

  sudo mkdir -p /usr/share/keyrings && \
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg && \
  #curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg && \
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.24:/1.24.6/xUbuntu_22.04//Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg && \
  sudo apt-get update && \
  sudo apt-get install cri-o cri-o-runc && \

  sudo apt-get install containernetworking-plugins
}

install_docker_engine () {
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

  # Add Docker's official GPG key:
  sudo apt-get update && \
  sudo apt-get install ca-certificates curl && \
  sudo install -m 0755 -d /etc/apt/keyrings && \
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
  sudo chmod a+r /etc/apt/keyrings/docker.asc && \

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  sudo apt-get update && \
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
  wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.9/cri-dockerd_0.3.9.3-0.ubuntu-jammy_amd64.deb && \
  sudo dpkg -i cri-dockerd_0.3.9.3-0.ubuntu-jammy_amd64.deb
}

sudo apt-get update

#Forwarding IPv4 and letting iptables see bridged traffic
#from https://kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

#verify that modules are loaded
sudo lsmod | grep br_netfilter

if [ "$?" -ne "0" ]; then
    echo "br_netfilter module not loaded... exiting...\n"
    exit 1
fi

sudo lsmod | grep overlay

if [ "$?" -ne "0" ]; then
    echo "overlay module not loaded... exiting...\n"
    exit 1
fi

#Verify that the net.bridge.bridge-nf-call-iptables,
#net.bridge.bridge-nf-call-ip6tables, and 
#net.ipv4.ip_forward system variables are set to 1 in your sysctl config
sudo sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

if [ "$?" -ne "0" ]; then
    echo "sysctl variables are wrong... exiting...\n"
    exit 1
fi

# configure / install kubelet kubeadm kubectl then put on hold
sudo apt-get update
sudo apt-get install ca-certificates curl 

dir="/etc/apt/keyrings"
if [ ! -d $dir ];then
  sudo mkdir -p $dir
fi

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

#update and install 
sudo apt-get update && \
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

# install cri
install_containerd

sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

if [ "$node" = "control_plane" ]; then
  #install for ifconfig to get ip
  sudo apt install net-tools

  # https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#initializing-your-control-plane-node
  ip_address=$(ifconfig eth0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')

  # set socket if cri is dockerd
  if [ "$cri" = "dockerd" ]; then
    cri_socket="--cri-socket=///var/run/cri-dockerd.sock"
  fi

  sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=$ip_address $cri_socket >> install_cluster.log

  #setup kubeconfig
  mkdir -p $HOME/.kube && \
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  if [ "$pod_network" = "weaveworks" ]; then
    #install pod network from https://kubernetes.io/docs/concepts/cluster-administration/addons/
    kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
    kubectl get ds -n kube-system weave-net -o yaml > weave_ds.yaml
    #sed -i 's/              fieldPath: spec.nodeName/              fieldPath: spec.nodeName\n        - name: IPALLOC_RANGE\n          value: 192.168.0.0\/16\n/' weave_ds.yaml
    sed -i '0,/              fieldPath: spec.nodeName/{s//              fieldPath: spec.nodeName\n        - name: IPALLOC_RANGE\n          value: 192.168.0.0\/16/}' weave_ds.yaml
    kubectl apply -f weave_ds.yaml
  fi
  # create worker node install / cluster join
  cp -f install_control_plane.sh install_cluster_worker_node.sh
  sed -i '0,/node=\"control_plane\"/{s//node=\"\"/}' install_cluster_worker_node.sh
  echo "" >> install_cluster_worker_node.sh
  grep -A1 "kubeadm join" install_cluster.log >> install_cluster_worker_node.sh
fi
