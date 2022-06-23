# Description
This repository contains the required Kubernetes manifests to deploy the infrastructure you need to start developing in Solana right away, using the [Indexer Stack](https://github.com/holaplex/indexer) that powers [Holaplex](https://holaplex.com) and many other projects in the ecosystem.
The steps below will describe how to deploy a *single node* Kubernetes cluster using `k3s` and all the components required to get up and running. Same steps apply if you are doing it locally or in any cloud provider. You should get a *Web2 like* development environment after completing all steps.

Disclaimer: The deployment is not meant to be used in production as it lacks of high availability.

## Components
- Solana RPC Node with [Holaplex Geyser Plugin](https://github.com/holaplex/indexer-geyser-plugin) (Optional)
- Indexer Stack | geyser-plugin - http-indexer - accounts-indexer - search-indexer - graphql-server - legacy-storefronts (Metaplex)
- IPFS/Arweave/Twitter assets CDN with caching and image processing using [Imgopt](https://github.com/holaplex/imgopt)
- RabbitMQ
- PostgresQL
- Meilisearch
- NGINX ingress controller
- Cert-Manager -with LetsEncrypt- (Optional)
- Keda (Optional)
- Example site using indexed data [Holaplex.com](https://github.com/holaplex/holaplex) [todo]

## Minimum hardware requirements
Hardware requirements are only as a guide to get a stable deployment. You can probably get away with deploying everything on a smaller VM if testing.
You could also only install what you need and that will also reduce the hardware needed.

Some instructions here will only work on Ubuntu `20.04` | `22.04` machines, but should be enough to understand what needs to be configured in any unix based operating system to make it work.
|   |Without Solana Node |With Solana Node   |
|---|---|---|
| vCPU  | 8   | 16  |
| RAM  | 32 GB  | 128 GB  |
| Disk (SSD)| 500 GB  | 2x 500GB  |

Keep in mind that whis Solana Node will not be staking, it will be used only as an RPC endpoint and to communicate with the other nodes to retrieve real-time updates that will be fed to the [Indexer Stack](https://github.com/holaplex/indexer).

You can also host the Solana node in a different VM and join that machine to the cluster after deploying  (This option will be described below as well).

## Dependencies
- [docker](https://docs.docker.com/engine/install/ubuntu/)
- [k3s](https://k3s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [jq](https://stedolan.github.io/jq/download/)

Steps to install all dependencies is described in the following steps.

# Getting started

### Preparing your VM
Create a Ubuntu 20.04 VM or spin up a cloud instance in your favourite provider and login as root trough SSH.
Commands below will add the Docker package repository and install some required OS dependencies.


```bash
# Installing Docker and jq
apt update && apt install lsb-release ca-certificates apt-transport-https software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt install docker-ce jq -y
```

### Installing application dependencies
Helm is a package manager for Kubernetes that will help us install some of the applications that will run in our cluster.
Kubectl is the CLI used to communicate with the Kubernetes API easily.

```bash
#Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
#Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

With everything installed, clone the `kubes` repository and `cd` into the folder.

```bash
git clone https://github.com/holaplex/kubes && cd kubes
```

# Creating a single-node Kubernetes cluster with k3s

Change minimum resources reserved by k3s and node hard evictions.

```bash
sudo mkdir -p /etc/rancher/k3s && \
cat <<EOF  | sudo tee -a /etc/rancher/k3s/config.yaml
kubelet-arg:
  - "kube-reserved=cpu=500m,memory=1Gi,ephemeral-storage=2Gi"
  - "system-reserved=cpu=500m, memory=1Gi,ephemeral-storage=2Gi"
  - "eviction-hard=memory.available<500Mi,nodefs.available<10%"
EOF
```

Before running the command below, replace `k3s.holaplex.tools` for your own domain. For localhost deployments you can use `k3s.127.0.0.1.nip.io` (Or `k3s.<network-ip>.nip.io` to access from LAN) and you'll be able to access to all the subdomains that we will create in the next steps without issues.
Check [nip.io](https://nip.io) for more info on how this works.

Install `k3s` using command below. This will start `k3s` as server.
```bash
#If you want to save your cluster data in a different path, add --data-dir /path/k3s
curl -sfL https://get.k3s.io | sh -s - server --no-deploy traefik servicelb --tls-san k3s.holaplex.tools --https-listen-port 6443
```

Retrieve your `kubectl` config from `/etc/rancher/k3s/k3s.yaml`, move it to your home `/.kube` folder.
Select your Kube configuration by changing your `KUBECONFIG` env var.
```bash
mkdir -p ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-indexer
#Add this line to your bash_profile to set permanently.
export KUBECONFIG=~/.kube/k3s-indexer
#echo "export KUBECONFIG=~/.kube/k3s-indexer" >> ~/.bash_profile
```

More deployment options (Like HA) available in [k3s docs](https://rancher.com/docs/k3s/latest/en/quick-start/)

### Validation
Check that your cluster is running
```bash
kubectl get pods -n kube-system
```

# MetalLB
Create MetalLB Namespace
```bash
kubectl apply -f ./metallb/namespace.yaml
```

Retrieve your IP address and apply the below MetalLB `configMap`

```bash
addresses=$(ip -4 addr show <your-network-interface>| grep -oP '(?<=inet\s)\d+(\.\d+){3}')
sed "s#LB_ADDRESSES#${addresses}#g" ./metallb/configMap.yaml | kubectl apply -f -
```

Deploy metallb
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/metallb.yaml
#Wait until Metallb is ready
kubectl wait --for=condition=Ready pod --timeout 60s -n metallb-system -l app=metallb -l component=speaker
```

# NGINX Ingress
```bash
kube_version=$(kubectl version -o json | jq -jr '. .serverVersion | .major, ".", .minor' | tr -d '+')
#Deploy nginx ingress using type LoadBalancer
curl -sfL https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/${kube_version}/deploy.yaml | sed 's#type: NodePort#type: LoadBalancer#g' | kubectl apply -f -
#Wait for deployment to complete
kubectl wait pod --for=condition=Ready --timeout 60s -n ingress-nginx -l app.kubernetes.io/component=controller
```

# Cert Manager
```bash
latest=$(curl -s https://api.github.com/repos/cert-manager/cert-manager/releases/latest | jq -r .tarball_url | cut -d/ -f8 | sed "s/v//g")
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --version $latest
```

# LetsEncrypt Issuers (Only if you need SSL Certs for your ingresses)
```bash
#Email address to use for cert renewal notifications
email="mariano@holaplex.com"
sed "s#YOUR_EMAIL#${email}#g" ./cert-manager/certissuers/letsencrypt.yaml | kubectl apply -f -
```

# Docker registry (skip if using any other public registry for your indexer images)
First we need a `registry` namespace.
```bash
kubectl create namespace registry
```

Now we are ready to deploy the registry itself.
Endpoint will be available at `registry.$domain`

```bash
domain="holaplex.tools"
volume_size=30 # In GB
#Modify ./docker-registry/registry.yaml before applying for more customizations
sed "s#YOUR_DOMAIN#${domain}#g;s#VOLUME_SIZE#${volume_size}#g" ./docker-registry/registry.yaml | kubectl apply -f -
```

Add the newly created registry to your node's cluster config and restart the `k3s` service.
```bash
sudo bash -c "cat <<EOF>> /etc/rancher/k3s/registries.yaml
mirrors:
  "registry.$domain":
    endpoint:
      - "http://registry.$domain"
EOF"
sudo systemctl restart k3s
```

# RabbitMQ
RabbitMQ Will be installed using Helm.

```bash
rabbitmq_user=changeme
rabbitmq_password="please-changeme"
kubectl create namespace rabbitmq-system
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm upgrade rabbitmq --install -n rabbitmq-system --create-namespace bitnami/rabbitmq \
  --set clustering.enabled=false \
  --set auth.username=$rabbitmq_user --set auth.password=$rabbitmq_password \
  --set persistence.size=50Gi \
  --wait
```

> More values to customize can be displayed by executing `helm show values bitnami/rabbitmq`
> Use `helm show values bitnami/rabbitmq > values.yaml` and then modify your `values.yaml` file.
> When ready, apply the chart adding the flag `-f values.yaml` when doing `helm install`.

Create virtualhost for the Indexer
```bash
rabbitmq_vhost=indexer
#Create virtual host
kubectl exec -it rabbitmq-0 -n rabbitmq-system -- rabbitmqctl add_vhost $rabbitmq_vhost
#Give permissions to your user
kubectl exec -it rabbitmq-0 -n rabbitmq-system -- rabbitmqctl set_permissions -p $rabbitmq_vhost $rabbitmq_user ".*" ".*" ".*"
```

Create an ingress for RabbitMQ console. Will be available at `rabbit.$domain`.
```bash
sed "s#YOUR_DOMAIN#${domain}#g" ./rabbitmq/ingress.yaml | kubectl apply -f -
```

# KEDA
Pod autoscaling for Rabbit Message queues.
```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
#Auto-scaling policies will be deployed later.
```

# Meilisearch
Add the Helm repo and update.

```bash
helm repo add meilisearch https://meilisearch.github.io/meilisearch-kubernetes
helm repo update
```

### Create master key
```bash
kubectl create namespace meilisearch
meili_token=$(openssl rand -hex 20)
kubectl create secret generic meili-master-key -n meilisearch --from-literal=MEILI_MASTER_KEY=$meili_token
#Save your meili_token somewhere safe
#echo $meili_token
```
You can also retrieve back the key from the cluster by executing:
```bash
kubectl get secret meili-master-key -n meilisearch -o 'jsonpath={.data.MEILI_MASTER_KEY}' | base64 -d
```

### Customizing Meilisearch values.
Open `./meilisearch/values.yaml` file and configure it to suit your needs.
When ready, trigger the install with the following command:
```bash
namespace=meilisearch
values_path=./meilisearch/values.yaml
helm upgrade -i meilisearch meilisearch/meilisearch -n $namespace --create-namespace -f $values_path --set environment.MEILI_ENV=development --set persistence.size=100Gi
```

Create an ingress for Meilisearch console. Available at `search.$domain`.
```bash
sed "s#YOUR_DOMAIN#${domain}#g" ./meilisearch/ingress.yaml | kubectl apply -f -
```
Endpoint will be `search.$domain`

# Postgres

### Install Postgres operator
helm upgrade --install postgres-operator --create-namespace ./postgres-operator/charts/postgres-operator -n postgres-system
helm upgrade --install postgres-operator-ui ./postgres-operator/charts/postgres-operator-ui -n postgres-system

Create a namespace for the `indexer` stack.
The Postgres cluster will be deployed there. This will only deploy 1 postgres instance unless modified in the variables below.

```bash
namespace=indexer
kubectl create namespace $namespace
# Move to the `indexer` namespace
kubectl config set-context --current --namespace=$namespace
```

### Deploy your postgres cluster
Configure variables
```bash
team=holaplex
app=indexer
db_cluster_name=indexerdb
db_cluster_instances=1
db_user=postgres
db_name=indexer
min_mem=8Gi
max_mem=16Gi
min_cpu_count=2
max_cpu_count=4
volume_size=300 #in GB
```
> Feel free to modify the yaml below before applying.

Deploy the cluster
```yaml
cat <<EOF | kubectl apply -f -
kind: "postgresql"
apiVersion: "acid.zalan.do/v1"
metadata:
  name: $team-$db_cluster_name
  namespace: $namespace
  labels:
    team: $team
    app: $app
spec:
  teamId: "$team"
  postgresql:
    version: "14"
  numberOfInstances: $db_cluster_instances
  enableMasterLoadBalancer: false
  enableReplicaLoadBalancer: false
  volume:
    size: ${volume_size}Gi
  users:
    $db_user: []
  databases:
    $db_name: $db_user
  allowedSourceRanges:
  resources:
    requests:
      cpu: ${min_cpu_count}000m
      memory: ${min_mem}
    limits:
      cpu: ${max_cpu_count}000m
      memory: ${max_mem}
EOF
```


### Validation
```bash
kubectl get postgresql/$team-$db_cluster_name -n $namespace -o wide
```
Your Postgres instance should show its status as `Running`

Create `indexer` database in Postgres
```bash
kubectl run postgresql-client-$(echo $RANDOM | md5sum | head -c4) -n $namespace --restart='Never' --image docker.io/bitnami/postgresql:14-debian-10 -- psql $(echo $DATABASE_URL | sed 's/\/indexer//g') -c "create database indexer"
```

# Indexer

### Building the docker images and pushing to local registry
Clone the indexer repo and cd into the folder

```bash
registry=registry.$domain ./indexer/build_images.sh
```

### Deploying to indexer stack
Before deploying, please setup your credentials by following [this readme](indexer/app/readme.md). *TLDR* version with some dummy values can be found below.
Move to the `indexer` namespace

```bash
namespace=indexer
#Move to the indexer namespace
kubectl config set-context --current --namespace=$namespace
```

Create credentials secrets.
```bash
rabbitmq_vhost=indexer
#Rabbit MQ
AMQP_URL="amqp://$rabbitmq_user:$rabbitmq_password@rabbitmq-headless.rabbitmq-system:5672/$rabbitmq_vhost"
kubectl create secret generic amqp-creds --from-literal=AMQP_URL="$AMQP_URL"
#Postgres | Retrieve creds and create a secret for the indexer
export PGPASSWORD=$(kubectl get secret $db_user.$team-$db_cluster_name.credentials.postgresql.acid.zalan.do -o 'jsonpath={.data.password}' | base64 -d)
export DATABASE_URL="postgres://$db_user:$PGPASSWORD@$team-$db_cluster_name.$namespace.svc:5432/$db_name"
kubectl create secret generic postgres-creds-url --from-literal=DATABASE_WRITE_URL="$DATABASE_URL" --from-literal=DATABASE_READ_URL="$DATABASE_URL"
#Meilisearch
meili_token=$(kubectl get secret meili-master-key -n meilisearch -o 'jsonpath={.data.MEILI_MASTER_KEY}' | base64 -d)
kubectl create secret generic meili-creds --from-literal=MEILI_URL="http://meilisearch.meilisearch:7700" --from-literal=MEILI_KEY="$meili_token"
#Dialect API
kubectl create secret generic dialect-creds --from-literal=DIALECT_API_ENDPOINT="https://api.dialect.io" --from-literal=DIALECT_API_KEY="<your-dialect-key>"
#Twitter creds
kubectl create secret generic twitter-creds --from-literal=TWITTER_BEARER_TOKEN="<twitter-token>"
```

Deploy the indexer stack
```bash
kubectl apply -f ./indexer/app
```

Deploy autoscaling policies for RabbitMQ queues

```bash
sed "s#stage-indexer#$namespace#g" indexer/app/mq-consumer-autoscaling-trigger.yaml | kubectl apply -f -
```

Deploy an ingress for GraphQL
Endpoint will be `graph.$domain`

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
    external-dns.alpha.kubernetes.io/hostname: graph.$domain
  labels:
    argocd.argoproj.io/instance: stage-indexer
  name: graphql
spec:
  ingressClassName: nginx
  rules:
  - host: graph.$domain
    http:
      paths:
      - backend:
          service:
            name: graphql
            port:
              number: 80
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - graph.$domain
    secretName: validator-tls
EOF
```

# Solana Node deployment

More info on how to deploy a validator (To use as reference is something is not working or want to learn more):
- [How to run a Solana node](https://chainstack.com/how-to-run-a-solana-node/) By Chainstack
- [Running a Solana validator](https://github.com/project-serum/validators) By Project Serum
- [Setting up a Solana devnet validator](https://github.com/agjell/sol-tutorials/blob/master/setting-up-a-solana-devnet-validator.md#introduction) Community guide
- [Starting a validator](https://docs.solana.com/running-validator/validator-start) Official Solana guide


Run only on the host that will run the Solana node.
```bash
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
sudo bash -c "echo -en [Services]\\nDefaultLimitNOFILE=1000000 >> /etc/systemd/system.conf"
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
```

Restart the instance
```bash
sudo shutdown -r now
```

Connect to the validator through SSH and join the node to the existing cluster.

```bash
#Download k3s and run join command.

#Retrieve kubeconfig

#download kubectl

#Test kubectl

```

Tag a node as a validator node in Kubernetes.

```bash
kubectl label nodes $HOSTNAME validator=true
```

### Download Solana CLI
```bash
sh -c "$(curl -sSfL https://release.solana.com/v1.10.5/install)"
#Add to PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH" >> $HOME/.bash_profile
```

### Generate a validator and vote-account keypair.
```bash
#chose devnet or mainnet-beta
network="mainnet-beta"
namespace="$network-solana"
kubectl create ns $namespace
#Move to the validator namespace
kubectl config set-context --current --namespace=$namespace
cd validator
solana-keygen new -o validator-keypair.json --silent --no-bip39-passphrase
solana-keygen new -o vote-account-keypair.json --silent --no-bip39-passphrase
```

### Create configMap with keypairs
```bash
kubectl create cm validator-keypairs --from-file=validator-keypair.json --from-file=vote-account-keypair.json
```

### Create certificates from ca-certificates to deployment
```bash
#get ca-certificates from /etc/ssl/certs/ca-certificates.crt after installing 'ca-certificates' package on your vm, or use the one provisioned in the validator folder.
kubectl create cm ca-certificates --from-file=ca-certificates.crt
```

### Create geyser-config configmap
```json
cat <<EOF>> ./$network/geyser-config.json
{
  "amqp": {
    "network": "$network",
    "address": "$AMQP_URL"
  },
  "libpath": "/geyser/libholaplex_indexer_rabbitmq_geyser.so",
  "jobs": {
    "limit": 16
  },
  "metrics": {
   "config": "host=http://influxdb-influxdb2.$namespace:80,db=$network,u=solana,p=your-custom-pw"
  },
  "accounts": {
    "owners": [
      "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s",
      "vau1zxA2LbssAUEF7Gpw91zMM1LvXrvpzJtmZ58rPsn",
      "auctxRXPeJoc4817jDhf4HbjnhEcr1cCXenosMhK5R8",
      "p1exdMJcjVao65QdewkaZRUnU6VPSXhus9n2GzWfh98",
      "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
      "hausS13jsjafwWwGqZTUQRmWyvyxn9EQpqMwV1PBBmk",
      "grphSXQnjAoPXSG5p1aJ7ZFw2A1akqP3pkXvjfbSJef",
      "cndy3Z4yapfJBmL3ShUp5exZKqR3z33thTzeNMm2gRZ",
      "namesLPneVptA9Z5rqUDD9tMTWEJwofgaYwp8cawRkX",
      "mgr99QFMYByTqGPWmNqunV7vBLmWWXdSrHUfV8Jf3JM",
      "pcaBwhJ1YHp7UDA7HASpQsRUmUNwzgYaLQto2kSj1fR",
      "tmeEDp1RgoDtZFtx6qod3HkbQmv9LMe36uqKVvsLTDE",
      "useZ65tbyvWpdYCLDJaegGK34Lnsi8S3jZdwx8122qp",
      "LocktDzaV1W2Bm9DeZeiyz4J9zs4fRqNiYqQyracRXw",
      "Govz1VyoyLD5BL6CSCxUJLVLsQHRwjfFj1prNsdNg5Jw",
      "GokivDYuQXPZCWRkwMhdH2h91KpDQXBEmpgBgs55bnpH"
    ],
    "startup": false
  },
  "instructionPrograms": []
}
EOF
kubectl create cm geyser-plugin-config --from-file=./$network/geyser-config.json
```

### Deploy the validator

Create a mount folder for the validator data and set the variable `validator_data_path` accordingly.
Ideally, you'll use a separate SSD for the ledger.
```bash
validator_data_path="/mnt/p3600/validator/$network"
sudo mkdir -p $validator_data_path && sudo chown $USER:$USER $validator_data_path
```

Create PersistentVolumes for the validator deployment and geyser plugin
```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $network-validator-data-pv
spec:
  capacity:
    storage: 500Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: ""
  claimRef:
    namespace: $namespace
    name: validator-data-pvc
  local:
    path: $validator_data_path
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: validator
          operator: In
          values:
          - "true"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: validator-data-pvc
  labels:
    app: validator
spec:
 storageClassName: ""
 accessModes:
   - ReadWriteOnce
 resources:
   requests:
      storage: 500Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: geyser-plugin-data-pvc
  labels:
    app: geyser-plugin
spec:
 storageClassName: ""
 accessModes:
   - ReadWriteOnce
 resources:
   requests:
      storage: 1Gi
EOF
```

Create a `configMap` with a startup script
```bash
kubectl create cm startup-script --from-file=./$network/startup.sh
```

Deploy the validator
```bash
kubectl apply -f ./$network/deploy.yaml -n $namespace
```

Expose the RPC endpoint (optional)
```bash
kubectl apply -f ./service.yaml -n $namespace
```

Create an ingress for the RPC Http endpoint
```yaml
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    external-dns.alpha.kubernetes.io/hostname: validator.$domain
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
  name: validator-rpc-http
spec:
  ingressClassName: nginx
  rules:
  - host: validator.$domain
    http:
      paths:
      - backend:
          service:
            name: rpc-ports
            port:
              name: rpc-http
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - validator.$domain
    secretName: validator-tls
EOF
```

Create an ingress for the RPC Websocket endpoint
```yaml
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    external-dns.alpha.kubernetes.io/hostname: validator.$domain
  name: validator-rpc-ws
spec:
  ingressClassName: nginx
  rules:
  - host: validator.$domain
    http:
      paths:
      - backend:
          service:
            name: rpc-ports
            port:
              name: rpc-http
        path: /ws
        pathType: Prefix
  tls:
  - hosts:
    - validator.$domain
    secretName: validator-tls
EOF
```
### Build the geyser plugin using Docker

Clone the repo
```bash
git clone https://github.com/holaplex/indexer-geyser-plugin ../indexer-geyser-plugin
```

Build the plugin
```bash
docker build -t geyser-plugin-builder --file plugin.Dockerfile ../indexer-geyser-plugin
```

Get the plugin from the container and upload it to the validator pod

```bash
container_id=$(docker run -d geyser-plugin-builder:latest sleep 300)
docker cp $container_id:/tmp/libholaplex_indexer_rabbitmq_geyser.so .
pod_name=$(kubectl get pods -n $namespace --no-headers | awk {'print $1'})
kubectl cp -c geyser-plugin-loader libholaplex_indexer_rabbitmq_geyser.so $namespace/$pod_name:/geyser
```

Wait for the validator to be ready
```bash
kubectl wait --for=condition=Ready pod --timeout 60s -n $namespace -l app=validator
```


### Validation
```bash
#Checking the logs
kubectl logs -f $pod_name -n $namespace -c validator
#Testing RPC endpoint
kubectl port-forward svc/validator -n $namespace 8899:8899
curl --silent localhost:8899 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0", "id":1, "method":"getBalance", "params":["EddYHALSPtgyPjjUmUrsBbgrfqUz6r8p61NKRhj3QPn3"]}' | jq .result.context.slot
```

Run `solana catchup` from the validator's container.
```bash
kubectl exec -it $pod_name -n $namespace -c validator -- solana catchup /root/validator-keypair.json
```

## Monitoring
Install `metrics-server` to get `kubectl top`.
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```


More advanced monitoring deployments will be added in the future, using Prometheus, Grafana and some sweet dashboards.
