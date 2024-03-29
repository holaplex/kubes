solana-validator  \
--identity=/root/validator-keypair.json \
--no-os-network-limits-test \
--no-port-check \
--log=- \
--accounts=/root/accounts \
--known-validator=dv1ZAGvdsz5hHLwWXsVnM94hWf1pjbKVau1QVkaMJ92 \
--known-validator=dv2eQHeP4RFrJZ6UeiZWoc3XTtmtZCUKxxCApCDcRNV \
--known-validator=dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB \
--known-validator=dv3qDFk1DTF36Z62bNvrCXe9sKATA6xvVy6A798xxAS \
--ledger=/ledger \
--rpc-port=10899 \
--full-rpc-api \
--entrypoint=entrypoint.devnet.solana.com:8001 \
--entrypoint=entrypoint2.devnet.solana.com:8001 \
--entrypoint=entrypoint3.devnet.solana.com:8001 \
--entrypoint=entrypoint4.devnet.solana.com:8001 \
--entrypoint=entrypoint5.devnet.solana.com:8001 \
--no-untrusted-rpc \
--no-voting \
--dynamic-port-range=8000-8013 \
--expected-genesis-hash=EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG \
--wal-recovery-mode=skip_any_corrupted_record \
--geyser-plugin-config=/root/geyser-config.json \
--limit-ledger-size \
--enable-rpc-transaction-history
