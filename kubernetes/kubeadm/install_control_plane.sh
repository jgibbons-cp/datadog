#!/bin/bash

# default containerd, cri_o for cri-o
cri=""
node="control_plane"
pod_network="cilium"
public_cp_endpoint=1
KUBERNETES_VERSION='v1.36'
VERSION_CODENAME=$KUBERNETES_VERSION
PAUSE_VERSION=3.10.1

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

  sudo apt install -y containerd

  containerd config default | sudo tee -a /etc/containerd/config.toml

  sed -i 's/pause:3.[0-9].[0-9]\+/pause:$PAUSE_VERSION/' /etc/containerd/config.toml && \

  sudo systemctl restart containerd
  sudo systemctl enable containerd
}

install_cri_o () {
  sudo apt-get install -y software-properties-common curl

  PROJECT_PATH=prerelease:/main

  curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key |
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" |
    sudo tee /etc/apt/sources.list.d/kubernetes.list

  curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/$PROJECT_PATH/deb/Release.key |
    sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

  echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] \
  https://pkgs.k8s.io/addons:/cri-o:/$PROJECT_PATH/deb/ /" |
    sudo tee /etc/apt/sources.list.d/cri-o.list

  sudo apt-get update
  sudo apt-get install -y cri-o kubelet kubeadm kubectl

  sudo systemctl start crio.service
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
#net.bridge.bridge-nf-call-iptables  = 1
#net.bridge.bridge-nf-call-ip6tables = 1
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
# net.bridge.bridge-nf-call-ip6tables, and 
#net.ipv4.ip_forward system variables are set to 1 in your sysctl config
sudo sysctl net.bridge.bridge-nf-call-iptables \
     net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

if [ "$?" -ne "0" ]; then
    echo "sysctl variables are wrong... exiting...\n"
    exit 1
fi

# configure / install kubelet kubeadm kubectl then put on hold
sudo apt-get update
sudo apt-get -y install apt-transport-https ca-certificates curl 

dir="/etc/apt/keyrings"
if [ ! -d $dir ];then
  sudo mkdir -p $dir
fi

key_url_beginning='https://pkgs.k8s.io/core:/stable:/'
key_url_end='/deb/Release.key'

curl -fsSL "$key_url_beginning$KUBERNETES_VERSION$key_url_end" | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

key='deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg]'
key_url_end='/deb/'

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo "$key $key_url_beginning$KUBERNETES_VERSION$key_url_end /" |
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

if [ "$cri" = "cri_o" ]; then
  install_cri_o
else
  install_containerd
fi

sudo apt-get install -y kubelet kubeadm kubectl

sudo apt-mark hold kubelet kubeadm kubectl

if [ "$node" = "control_plane" ]; then
  
  #install for ifconfig to get ip
  sudo apt install net-tools

  # https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#initializing-your-control-plane-node
  device=$(ip -o link show | awk -F': ' '$2 ~ /^en/ {print $2; exit}')
  private_ip_address=$(ifconfig $device | 
    sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')

    # api server public or not
  if [ "$public_cp_endpoint" = "1" ]; then
    public_ip_address=$(curl http://checkip.amazonaws.com)
    
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 \
      --control-plane-endpoint=$public_ip_address $cri_socket \
      >> install_cluster.log


    #sed -i "s/PUBLIC_IP/$public_ip_address/" kubelet_patch.yaml
    #sed -i "s/LOCAL_IP/$private_ip_address/" kubelet_patch.yaml
    #TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    #hostname=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-hostname)
    #sed -i "s/HOSTNAME/$hostname/" kubelet_patch.yaml

    #sudo kubeadm init --config kubelet_patch.yaml >> install_cluster.log

  else
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 \
      --apiserver-advertise-address=$private_ip_address \
      $cri_socket >> install_cluster.log
  fi

  #setup kubeconfig
  mkdir -p $HOME/.kube && \
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  if [ "$pod_network" = "cilium" ]; then
    helm > /dev/null
    if [ "$?" -ne "0" ]; then
      # install helm
      curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
      chmod 700 get_helm.sh
      ./get_helm.sh
    fi

    # install cilium
    curl -LO https://github.com/cilium/cilium/archive/main.tar.gz
    tar xzf main.tar.gz
    cd cilium-main/install/kubernetes
    helm install cilium ./cilium --namespace kube-system
  fi

  # if want to taint node - tested code
  #kubectl get configmap kubelet-config -n kube-system -o yaml > running_kubelet_config.yaml
  #sed -i 's/volumeStatsAggPeriod: 0s/volumeStatsAggPeriod: 0s\n    registerWithTaints:\n      - key: \"datadog\"\n        effect: \"NoSchedule\"\n/' running_kubelet_config.yaml
  #kubectl apply -f running_kubelet_config.yaml
  #sudo kubeadm upgrade node phase kubelet-config
  #sudo systemctl restart kubelet
  #sleep 20
  # create worker node install / cluster join

  cd /home/ubuntu
  cp -f install_control_plane.sh install_cluster_worker_node.sh 
  sed -i '0,/node=\"control_plane\"/{s//node=\"\"/}' \
    install_cluster_worker_node.sh
  echo "" >> install_cluster_worker_node.sh
  grep -A1 "kubeadm join" install_cluster.log \
    >> install_cluster_worker_node.sh
  sed -i 's/--discovery-token-ca-cert-hash/$cri_socket \--discovery-token-ca-cert-hash'/ \
    install_cluster_worker_node.sh

  # install k8s bash completion
  kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
fi