# solana-attestation-pipe

Pipes indexer for solana attestation data

TODO: fill 

```
yarn install

docker compose up -d

yarn start
```

`docker compose down -v` then `docker compose up -d` to restart the db and the indexer



to get the last 10 attestations run 
```
docker exec -it soldexer_clickhouse clickhouse-client --query "SELECT slot, timestamp, credential, schema, authority, claim_json, expiry FROM attestations_raw ORDER BY slot DESC LIMIT 10;"
```

Combine this pipe with other attestation pipes in a modular way to perform powerful requests.