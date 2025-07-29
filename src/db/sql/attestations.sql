-- Raw table for credentials
CREATE TABLE IF NOT EXISTS credentials_raw (
  slot                UInt64,
  timestamp           DateTime CODEC (DoubleDelta, ZSTD),
  instruction_type    String,
  transaction_hash    String,
  credential_pda      String,
  authority           String,
  name                String,
  signers             Array(String),
  previous_signers    Array(String) DEFAULT []
) ENGINE = MergeTree()
ORDER BY (slot, credential_pda);

-- Raw table for schemas
CREATE TABLE IF NOT EXISTS schemas_raw (
  slot                UInt64,
  timestamp           DateTime CODEC (DoubleDelta, ZSTD),
  instruction_type    String,
  transaction_hash    String,
  schema_pda          String,
  credential_pda      String,
  authority           String,
  name                String,
  description         String,
  previous_description String DEFAULT '',
  layout_buffer       String,
  field_names         Array(String),
  is_paused           UInt8 DEFAULT 0,
  previous_status     UInt8 DEFAULT 0,
  existing_schema_pda String DEFAULT '',
  new_schema_pda      String DEFAULT ''
) ENGINE = MergeTree()
ORDER BY (slot, schema_pda);

-- Raw table for attestations
CREATE TABLE IF NOT EXISTS attestations_raw (
  slot                UInt64,
  timestamp           DateTime CODEC (DoubleDelta, ZSTD),
  instruction_type    String,
  transaction_hash    String,
  attestation_pda     String,
  credential_pda      String,
  schema_pda          String,
  authority           String,
  nonce               String DEFAULT '',
  claim_data          String,
  expiry              Int64 DEFAULT 0,
  is_tokenized        UInt8 DEFAULT 0,
  token_name          String DEFAULT '',
  token_uri           String DEFAULT '',
  token_symbol        String DEFAULT '',
  mint_account_space  UInt16 DEFAULT 0,
  attestation_mint    String DEFAULT '',
  schema_mint         String DEFAULT '',
  recipient           String DEFAULT '',
  recipient_token_account String DEFAULT ''
) ENGINE = MergeTree()
ORDER BY (slot, attestation_pda);

-- Raw table for tokenization events
CREATE TABLE IF NOT EXISTS tokenization_raw (
  slot                UInt64,
  timestamp           DateTime CODEC (DoubleDelta, ZSTD),
  instruction_type    String,
  transaction_hash    String,
  schema_pda          String,
  credential_pda      String,
  authority           String,
  mint_pda            String,
  max_size            UInt64,
  sas_pda             String
) ENGINE = MergeTree()
ORDER BY (slot, schema_pda);

-- Raw table for events
CREATE TABLE IF NOT EXISTS events_raw (
  slot                UInt64,
  timestamp           DateTime CODEC (DoubleDelta, ZSTD),
  instruction_type    String,
  transaction_hash    String,
  event_authority     String,
  event_data          String DEFAULT ''
) ENGINE = MergeTree()
ORDER BY (slot, event_authority);

-- Materialized views for analytics
CREATE MATERIALIZED VIEW IF NOT EXISTS credentials_summary
ENGINE = AggregatingMergeTree()
ORDER BY (hour, authority)
AS
SELECT
  toStartOfHour(timestamp) AS hour,
  authority,
  countState() AS total_credentials
FROM credentials_raw
WHERE instruction_type = 'createCredential'
GROUP BY hour, authority;

CREATE MATERIALIZED VIEW IF NOT EXISTS schemas_summary
ENGINE = AggregatingMergeTree()
ORDER BY (hour, credential_pda)
AS
SELECT
  toStartOfHour(timestamp) AS hour,
  credential_pda,
  countState() AS total_schemas,
  countIfState(is_paused = 0) AS active_schemas
FROM schemas_raw
WHERE instruction_type = 'createSchema'
GROUP BY hour, credential_pda;

CREATE MATERIALIZED VIEW IF NOT EXISTS attestations_hourly_summary
ENGINE = AggregatingMergeTree()
ORDER BY (hour, schema_pda)
AS
SELECT
  toStartOfHour(timestamp) AS hour,
  schema_pda,
  countState() AS total_issued,
  countIfState(is_tokenized = 1) AS tokenized_count
FROM attestations_raw
WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
GROUP BY hour, schema_pda;
