### Creating amqp credentials secret
```bash
kubectl create secret generic amqp-creds --from-literal=AMQP_URL="amqps://<user>:<pw>@<host>:<port>/<vhost>"
```

### Creating secret manifest with tokens
```bash
kubectl create secret generic hola-secrets \
--from-literal=NFT_STORAGE_API_KEY="<storage-api-key>" \
--from-literal=NEXT_PUBLIC_MIXPANEL_TOKEN="<your-token>" \
--from-literal=NEXT_PUBLIC_META_ID="<meta-id>"
```
