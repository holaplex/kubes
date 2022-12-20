## Deploy instructions

- configure `START_SLOT` and `END_SLOT` accordingly in [reindex-config.yaml](https://github.com/holaplex/kubes/blob/dev/indexer/mainnet/app/jobs/slot-reindex/reindex-config.yaml#L4-L5)
- add/remove programs you want to reindex in [programs-config.yaml](https://github.com/holaplex/kubes/blob/dev/indexer/mainnet/app/jobs/slot-reindex/programs-config.yaml)
- set deployment replica count to `1` in [deployment.yaml](https://github.com/holaplex/kubes/blob/dev/indexer/mainnet/app/jobs/slot-reindex/deployment.yaml#L8)
- commit and push
