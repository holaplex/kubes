#!/bin/bash
apt update && apt install lsb-release ca-certificates apt-transport-https software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update && apt install docker-ce jq -y


#Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
#Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

mkdir -p /etc/rancher/k3s && \
cat <<EOF  | sudo tee -a /etc/rancher/k3s/config.yaml
kubelet-arg:
  - "kube-reserved=cpu=500m,memory=1Gi,ephemeral-storage=2Gi"
  - "system-reserved=cpu=500m, memory=1Gi,ephemeral-storage=2Gi"
  - "eviction-hard=memory.available<500Mi,nodefs.available<10%"
EOF

curl -sfL https://get.k3s.io | sh -s - server --disable traefik --disable servicelb --tls-san k3s.devnet.holaplex.tools --https-listen-port 6443


#Increase UDP buffers
sudo bash -c "cat >/etc/sysctl.d/20-solana-udp-buffers.conf <<EOF
# Increase UDP buffer size
net.core.rmem_default = 134217728
net.core.rmem_max = 134217728
net.core.wmem_default = 134217728
net.core.wmem_max = 134217728
EOF"
sudo sysctl -p /etc/sysctl.d/20-solana-udp-buffers.conf
#Increase memory mapped files limit
sudo bash -c "cat >/etc/sysctl.d/20-solana-mmaps.conf <<EOF
# Increase memory mapped files limit
vm.max_map_count = 1000000
EOF"
sudo sysctl -p /etc/sysctl.d/20-solana-mmaps.conf
echo -en "DefaultLimitNOFILE=1000000" | sudo tee -a /etc/systemd/system.conf
sudo systemctl daemon-reload
sudo bash -c "cat >/etc/security/limits.d/90-solana-nofiles.conf <<EOF
# Increase process file descriptor count limit
* - nofile 1000000
EOF"


#Create big Swap file
sudo fallocate -l 128G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
#Activate the swap file
sudo swapon /swapfile
#Add to fstab
echo "/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab


#Move kubectl to home
mkdir -p ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-indexer
#Add this line to your bash_profile to set permanently.
export KUBECONFIG=~/.kube/k3s-indexer
echo "export KUBECONFIG=~/.kube/k3s-indexer" >> ~/.bash_profile
