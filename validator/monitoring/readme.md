## Influx DB
```bash
#Set variables accordingly
domain=devnet.holaplex.tools
team=holaplex
bucket_name=devnet
influxdb_user=solana
influxdb_pw=$(openssl rand -hex 20)
influxdb_volume_size=50 # in GB
```

## Install with helm
```bash
helm repo add influxdata https://helm.influxdata.com/
helm repo update
helm upgrade telegraf --install influxdata/telegraf-operator --namespace monitoring --create-namespace -f ./validator/monitoring/telegraf-values.yaml --wait
helm upgrade --install influxdb influxdata/influxdb2 --namespace monitoring --create-namespace -f ./validator/monitoring/influxdb-values.yaml --set adminUser.organization=$team --set persistence.size=${influxdb_volume_size}Gi --set ingress.hostname=influxdb.$domain --wait
```

## Create and configure bucket to send metrics
```bash
#External DNS ANnotation
kubectl annotate ing influxdb-influxdb2 --overwrite "external-dns.alpha.kubernetes.io/hostname=influxdb.$domain"
#Retrieve influxdb pw
INFLUX_TOKEN=$(kubectl get secret influxdb-influxdb2-auth -o json | jq -r '.data."admin-token"' | base64 -d)
#influx bucket list
kubectl exec -it influxdb-influxdb2-0 -n monitoring -- influx bucket list --org holaplex -t $INFLUX_TOKEN
#Set default config
kubectl exec -it influxdb-influxdb2-0  -- influx config create --host-url http://influxdb-influxdb2 --config-name default -t $INFLUX_TOKEN --org $team
#Create bucket for solana metrics
kubectl exec -it influxdb-influxdb2-0 -- influx bucket create --org $team -n $bucket_name
#Add permissions to our user to send data
bucket_id=$(kubectl exec -it influxdb-influxdb2-0 -- influx bucket list --org $team -n $bucket_name --json | jq -r '.[] | .id')
kubectl exec -it influxdb-influxdb2-0 --  influx v1 auth create -o $team --username solana --password $influxdb_pw --read-bucket $bucket_id --write-bucket $bucket_id
#configure bucket retention policy
kubectl exec -it influxdb-influxdb2-0 -- influx v1 dbrp create --db $bucket_name --rp default --bucket-id $bucket_id -o $team
```
