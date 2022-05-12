This deployment expects to have a few secrets created:
 - `postgres-creds-url` with the read and write database URLs.
 - `amqp-creds` with RabbitMQ Endpoint (AMQP_URL)
 - `twitter-creds` with Twitter bearer token
 - `dialect-creds` with Dialect API KEY and Endpoint
 - `meili-creds` with MeiliSearch API KEY and Endpoint

Deploy those using the commands below before proceeding with the application deployment.

### Creating database credentials secret
```bash
kubectl create secret generic postgres-creds \
--from-literal=DATABASE_WRITE_URL="postgres://<user>:<pw>@<host>:5432/<db_name>" \
--from-literal=DATABASE_READ_URL="postgres://<user>:<pw>@<host>:5432/<db_name>" \
```

### Creating twitter credentials secret
```bash
kubectl create secret generic twitter-creds \
--from-literal=TWITTER_BEARER_TOKEN="<twitter-token>"
```

### Creating amqp credentials secret
```bash
kubectl create secret generic amqp-creds --from-literal=AMQP_URL="amqps://<user>:<pw>@<host>:<port>/<vhost>"
```

### Creating dialect API KEY secret
```bash
kubectl create secret generic dialect-creds --from-literal=DIALECT_API_ENDPOINT="<dialect-endpoint>" --from-literal=DIALECT_API_KEY="<api-key>"
```

### Creating Meilisearch secret
```bash
kubectl create secret generic meili-creds --from-literal=MEILI_URL="<meilisearch-endpoint>" --from-literal=MEILI_KEY="<api-key>"
```
