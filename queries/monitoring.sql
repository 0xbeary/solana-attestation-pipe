-- Real-time monitoring queries for Solana Attestation Service
-- Use these for dashboards and alerting systems

-- =============================================================================
-- REAL-TIME ACTIVITY MONITORING
-- =============================================================================

-- 1. Live instruction stream (last 100 instructions)
SELECT 
    timestamp,
    instruction_type,
    CASE 
        WHEN instruction_type LIKE '%Credential%' THEN credential_pda
        WHEN instruction_type LIKE '%Schema%' THEN schema_pda  
        WHEN instruction_type LIKE '%Attestation%' THEN attestation_pda
        ELSE 'N/A'
    END as primary_account,
    authority,
    slot,
    transaction_hash
FROM (
    SELECT timestamp, instruction_type, credential_pda, '' as schema_pda, '' as attestation_pda, authority, slot, transaction_hash FROM credentials_raw
    UNION ALL
    SELECT timestamp, instruction_type, credential_pda, schema_pda, '' as attestation_pda, authority, slot, transaction_hash FROM schemas_raw
    UNION ALL
    SELECT timestamp, instruction_type, credential_pda, schema_pda, attestation_pda, authority, slot, transaction_hash FROM attestations_raw
    UNION ALL
    SELECT timestamp, instruction_type, credential_pda, schema_pda, '' as attestation_pda, authority, slot, transaction_hash FROM tokenization_raw
    UNION ALL
    SELECT timestamp, instruction_type, '' as credential_pda, '' as schema_pda, '' as attestation_pda, event_authority as authority, slot, transaction_hash FROM events_raw
) all_instructions
ORDER BY timestamp DESC
LIMIT 100;

-- 2. Current hour activity summary
SELECT 
    instruction_type,
    COUNT(*) as count_this_hour,
    COUNT(DISTINCT authority) as unique_authorities
FROM (
    SELECT instruction_type, authority FROM credentials_raw WHERE timestamp >= toStartOfHour(now())
    UNION ALL
    SELECT instruction_type, authority FROM schemas_raw WHERE timestamp >= toStartOfHour(now())
    UNION ALL
    SELECT instruction_type, authority FROM attestations_raw WHERE timestamp >= toStartOfHour(now())
    UNION ALL
    SELECT instruction_type, authority FROM tokenization_raw WHERE timestamp >= toStartOfHour(now())
    UNION ALL
    SELECT instruction_type, event_authority as authority FROM events_raw WHERE timestamp >= toStartOfHour(now())
) current_hour
GROUP BY instruction_type
ORDER BY count_this_hour DESC;

-- 3. Active schemas (schemas that received attestations in last 24h)
SELECT 
    s.schema_pda,
    s.name as schema_name,
    s.credential_pda,
    COUNT(a.attestation_pda) as attestations_24h,
    COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) as tokenized_24h,
    MAX(a.timestamp) as last_attestation
FROM schemas_raw s
JOIN attestations_raw a ON s.schema_pda = a.schema_pda 
WHERE s.instruction_type = 'createSchema'
  AND a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
  AND a.timestamp >= now() - INTERVAL 24 HOUR
GROUP BY s.schema_pda, s.name, s.credential_pda
ORDER BY attestations_24h DESC;

-- =============================================================================
-- HEALTH MONITORING
-- =============================================================================

-- 4. Indexing lag detection
SELECT 
    table_name,
    latest_slot,
    latest_timestamp,
    now() - latest_timestamp as indexing_lag_seconds,
    CASE 
        WHEN now() - latest_timestamp > INTERVAL 5 MINUTE THEN 'CRITICAL'
        WHEN now() - latest_timestamp > INTERVAL 2 MINUTE THEN 'WARNING'
        ELSE 'OK'
    END as status
FROM (
    SELECT 'credentials' as table_name, MAX(slot) as latest_slot, MAX(timestamp) as latest_timestamp FROM credentials_raw
    UNION ALL
    SELECT 'schemas', MAX(slot), MAX(timestamp) FROM schemas_raw
    UNION ALL
    SELECT 'attestations', MAX(slot), MAX(timestamp) FROM attestations_raw
    UNION ALL
    SELECT 'tokenization', MAX(slot), MAX(timestamp) FROM tokenization_raw
    UNION ALL
    SELECT 'events', MAX(slot), MAX(timestamp) FROM events_raw
) lag_check
ORDER BY indexing_lag_seconds DESC;

-- 5. Error detection - unusual patterns
WITH instruction_counts AS (
    SELECT 
        toStartOfHour(timestamp) as hour,
        instruction_type,
        COUNT(*) as hourly_count
    FROM (
        SELECT timestamp, instruction_type FROM credentials_raw WHERE timestamp >= now() - INTERVAL 24 HOUR
        UNION ALL
        SELECT timestamp, instruction_type FROM schemas_raw WHERE timestamp >= now() - INTERVAL 24 HOUR
        UNION ALL
        SELECT timestamp, instruction_type FROM attestations_raw WHERE timestamp >= now() - INTERVAL 24 HOUR
    ) recent_data
    GROUP BY hour, instruction_type
),
avg_counts AS (
    SELECT 
        instruction_type,
        AVG(hourly_count) as avg_hourly,
        stddevPop(hourly_count) as stddev_hourly
    FROM instruction_counts
    GROUP BY instruction_type
)
SELECT 
    ic.hour,
    ic.instruction_type,
    ic.hourly_count,
    ac.avg_hourly,
    CASE 
        WHEN ic.hourly_count > ac.avg_hourly + 3 * ac.stddev_hourly THEN 'SPIKE'
        WHEN ic.hourly_count < ac.avg_hourly - 2 * ac.stddev_hourly AND ac.avg_hourly > 1 THEN 'DROP'
        ELSE 'NORMAL'
    END as anomaly_status
FROM instruction_counts ic
JOIN avg_counts ac ON ic.instruction_type = ac.instruction_type
WHERE ic.hour >= now() - INTERVAL 6 HOUR
ORDER BY ic.hour DESC, ic.instruction_type;

-- =============================================================================
-- PERFORMANCE METRICS
-- =============================================================================

-- 6. Transaction throughput per minute (last hour)
SELECT 
    toStartOfMinute(timestamp) as minute,
    COUNT(DISTINCT transaction_hash) as unique_transactions,
    COUNT(*) as total_instructions,
    COUNT(*) / 60.0 as instructions_per_second
FROM (
    SELECT timestamp, transaction_hash FROM credentials_raw WHERE timestamp >= now() - INTERVAL 1 HOUR
    UNION ALL
    SELECT timestamp, transaction_hash FROM schemas_raw WHERE timestamp >= now() - INTERVAL 1 HOUR
    UNION ALL
    SELECT timestamp, transaction_hash FROM attestations_raw WHERE timestamp >= now() - INTERVAL 1 HOUR
    UNION ALL
    SELECT timestamp, transaction_hash FROM tokenization_raw WHERE timestamp >= now() - INTERVAL 1 HOUR
    UNION ALL
    SELECT timestamp, transaction_hash FROM events_raw WHERE timestamp >= now() - INTERVAL 1 HOUR
) last_hour
GROUP BY minute
ORDER BY minute DESC;

-- 7. Top active authorities (last 24h)
SELECT 
    authority,
    COUNT(*) as total_instructions,
    COUNT(DISTINCT CASE WHEN table_type = 'credentials' THEN pda END) as credentials_managed,
    COUNT(DISTINCT CASE WHEN table_type = 'schemas' THEN pda END) as schemas_managed, 
    COUNT(DISTINCT CASE WHEN table_type = 'attestations' THEN pda END) as attestations_created,
    MAX(timestamp) as last_activity
FROM (
    SELECT authority, credential_pda as pda, 'credentials' as table_type, timestamp FROM credentials_raw WHERE timestamp >= now() - INTERVAL 24 HOUR
    UNION ALL
    SELECT authority, schema_pda as pda, 'schemas' as table_type, timestamp FROM schemas_raw WHERE timestamp >= now() - INTERVAL 24 HOUR
    UNION ALL
    SELECT authority, attestation_pda as pda, 'attestations' as table_type, timestamp FROM attestations_raw WHERE timestamp >= now() - INTERVAL 24 HOUR
) active_authorities
GROUP BY authority
ORDER BY total_instructions DESC
LIMIT 20;

-- =============================================================================
-- BUSINESS METRICS
-- =============================================================================

-- 8. Attestation success rate (creations vs closures)
SELECT 
    DATE(timestamp) as date,
    COUNT(CASE WHEN instruction_type IN ('createAttestation', 'createTokenizedAttestation') THEN 1 END) as attestations_created,
    COUNT(CASE WHEN instruction_type IN ('closeAttestation', 'closeTokenizedAttestation') THEN 1 END) as attestations_closed,
    (COUNT(CASE WHEN instruction_type IN ('createAttestation', 'createTokenizedAttestation') THEN 1 END) - 
     COUNT(CASE WHEN instruction_type IN ('closeAttestation', 'closeTokenizedAttestation') THEN 1 END)) as net_attestations
FROM attestations_raw 
WHERE timestamp >= now() - INTERVAL 7 DAY
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- 9. Tokenization adoption rate
SELECT 
    DATE(timestamp) as date,
    COUNT(CASE WHEN instruction_type = 'createAttestation' THEN 1 END) as regular_attestations,
    COUNT(CASE WHEN instruction_type = 'createTokenizedAttestation' THEN 1 END) as tokenized_attestations,
    COUNT(CASE WHEN instruction_type = 'createTokenizedAttestation' THEN 1 END) * 100.0 / 
    (COUNT(CASE WHEN instruction_type = 'createAttestation' THEN 1 END) + 
     COUNT(CASE WHEN instruction_type = 'createTokenizedAttestation' THEN 1 END)) as tokenization_rate
FROM attestations_raw 
WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
  AND timestamp >= now() - INTERVAL 7 DAY
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- 10. Schema utilization distribution
SELECT 
    schema_usage_bucket,
    COUNT(*) as schema_count,
    SUM(total_attestations) as total_attestations_in_bucket
FROM (
    SELECT 
        schema_pda,
        COUNT(*) as total_attestations,
        CASE 
            WHEN COUNT(*) = 1 THEN '1 attestation'
            WHEN COUNT(*) <= 5 THEN '2-5 attestations'
            WHEN COUNT(*) <= 20 THEN '6-20 attestations'
            WHEN COUNT(*) <= 100 THEN '21-100 attestations'
            ELSE '100+ attestations'
        END as schema_usage_bucket
    FROM attestations_raw 
    WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    GROUP BY schema_pda
) schema_usage
GROUP BY schema_usage_bucket
ORDER BY 
    CASE schema_usage_bucket
        WHEN '1 attestation' THEN 1
        WHEN '2-5 attestations' THEN 2
        WHEN '6-20 attestations' THEN 3
        WHEN '21-100 attestations' THEN 4
        WHEN '100+ attestations' THEN 5
    END;
