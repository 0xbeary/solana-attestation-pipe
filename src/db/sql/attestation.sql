-- raw table
CREATE TABLE IF NOT EXISTS attestations_raw (
  slot         UInt64,
  timestamp    DateTime CODEC (DoubleDelta, ZSTD),
  credential   String,
  schema       String,
  authority    String,
  claim_json   String,
  expiry       UInt64
) ENGINE = MergeTree()
ORDER BY (slot);

-- materialized view: e.g. count per schema per hour
CREATE MATERIALIZED VIEW IF NOT EXISTS attestations_hourly_summary
ENGINE = AggregatingMergeTree()
ORDER BY (hour, schema)
AS
SELECT
  toStartOfHour(timestamp) AS hour,
  schema,
  countState() AS total_issued
FROM attestations_raw
GROUP BY hour, schema;
