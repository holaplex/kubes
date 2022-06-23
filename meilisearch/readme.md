### Add meilisearch repo to Helm

```bash
helm repo add meilisearch https://meilisearch.github.io/meilisearch-kubernetes
helm repo update
```

### create master key
```bash
kubectl create secret generic meili-master-key --from-literal=MEILI_MASTER_KEY=<your-master-key>
```

### Values.yaml setup
Open `values.yaml` file and configure it to suit your needs.
Trigger the install with the following command:
```bash
namespace=prod-meilisearch
helm upgrade -i meilisearch meilisearch/meilisearch -n $namespace --create-namespace -f values.yaml
```

### Patch the created ingress increasing timeout to a higher value
```bash
kubectl patch ing meilisearch --patch-file ingress-patch.yaml -n $namespace
```
