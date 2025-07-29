-- Dashboard Queries for Solana Attestation Service
-- Quick metrics for executive dashboards and summary views

-- =============================================================================
-- EXECUTIVE SUMMARY METRICS
-- =============================================================================

-- 1. Key Performance Indicators (KPIs)
SELECT 
    'Total Credentials' as metric,
    toString(COUNT(*)) as value,
    'Lifetime' as period
FROM credentials_raw 
WHERE instruction_type = 'createCredential'

UNION ALL

SELECT 
    'Total Schemas' as metric,
    toString(COUNT(*)) as value,
    'Lifetime' as period
FROM schemas_raw 
WHERE instruction_type = 'createSchema'

UNION ALL

SELECT 
    'Total Attestations' as metric,
    toString(COUNT(*)) as value,
    'Lifetime' as period
FROM attestations_raw 
WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')

UNION ALL

SELECT 
    'Tokenization Rate' as metric,
    toString(ROUND(COUNT(CASE WHEN is_tokenized = 1 THEN 1 END) * 100.0 / COUNT(*), 1)) || '%' as value,
    'Lifetime' as period
FROM attestations_raw 
WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')

UNION ALL

SELECT 
    'Active Authorities (30d)' as metric,
    toString(COUNT(DISTINCT authority)) as value,
    'Last 30 days' as period
FROM (
    SELECT authority FROM credentials_raw WHERE timestamp >= now() - INTERVAL 30 DAY
    UNION
    SELECT authority FROM schemas_raw WHERE timestamp >= now() - INTERVAL 30 DAY
    UNION
    SELECT authority FROM attestations_raw WHERE timestamp >= now() - INTERVAL 30 DAY
) recent_authorities

UNION ALL

SELECT 
    'Avg Attestations per Schema' as metric,
    toString(ROUND(COUNT(a.attestation_pda) * 1.0 / COUNT(DISTINCT s.schema_pda), 1)) as value,
    'Lifetime' as period
FROM schemas_raw s
LEFT JOIN attestations_raw a ON s.schema_pda = a.schema_pda 
    AND a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
WHERE s.instruction_type = 'createSchema';

-- =============================================================================
-- GROWTH TRENDS (7-day trends)
-- =============================================================================

-- 2. Weekly growth comparison
WITH this_week AS (
    SELECT 
        COUNT(CASE WHEN table_name = 'credentials' THEN 1 END) as credentials_this_week,
        COUNT(CASE WHEN table_name = 'schemas' THEN 1 END) as schemas_this_week,
        COUNT(CASE WHEN table_name = 'attestations' THEN 1 END) as attestations_this_week
    FROM (
        SELECT 'credentials' as table_name FROM credentials_raw 
        WHERE instruction_type = 'createCredential' AND timestamp >= now() - INTERVAL 7 DAY
        UNION ALL
        SELECT 'schemas' FROM schemas_raw 
        WHERE instruction_type = 'createSchema' AND timestamp >= now() - INTERVAL 7 DAY
        UNION ALL
        SELECT 'attestations' FROM attestations_raw 
        WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation') 
        AND timestamp >= now() - INTERVAL 7 DAY
    ) this_week_data
),
last_week AS (
    SELECT 
        COUNT(CASE WHEN table_name = 'credentials' THEN 1 END) as credentials_last_week,
        COUNT(CASE WHEN table_name = 'schemas' THEN 1 END) as schemas_last_week,
        COUNT(CASE WHEN table_name = 'attestations' THEN 1 END) as attestations_last_week
    FROM (
        SELECT 'credentials' as table_name FROM credentials_raw 
        WHERE instruction_type = 'createCredential' 
        AND timestamp >= now() - INTERVAL 14 DAY 
        AND timestamp < now() - INTERVAL 7 DAY
        UNION ALL
        SELECT 'schemas' FROM schemas_raw 
        WHERE instruction_type = 'createSchema' 
        AND timestamp >= now() - INTERVAL 14 DAY 
        AND timestamp < now() - INTERVAL 7 DAY
        UNION ALL
        SELECT 'attestations' FROM attestations_raw 
        WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation') 
        AND timestamp >= now() - INTERVAL 14 DAY 
        AND timestamp < now() - INTERVAL 7 DAY
    ) last_week_data
)
SELECT 
    'Credentials Growth' as metric,
    toString(tw.credentials_this_week) as this_week,
    toString(lw.credentials_last_week) as last_week,
    CASE 
        WHEN lw.credentials_last_week = 0 THEN 'N/A'
        ELSE toString(ROUND((tw.credentials_this_week - lw.credentials_last_week) * 100.0 / lw.credentials_last_week, 1)) || '%'
    END as change
FROM this_week tw, last_week lw

UNION ALL

SELECT 
    'Schemas Growth' as metric,
    toString(tw.schemas_this_week) as this_week,
    toString(lw.schemas_last_week) as last_week,
    CASE 
        WHEN lw.schemas_last_week = 0 THEN 'N/A'
        ELSE toString(ROUND((tw.schemas_this_week - lw.schemas_last_week) * 100.0 / lw.schemas_last_week, 1)) || '%'
    END as change
FROM this_week tw, last_week lw

UNION ALL

SELECT 
    'Attestations Growth' as metric,
    toString(tw.attestations_this_week) as this_week,
    toString(lw.attestations_last_week) as last_week,
    CASE 
        WHEN lw.attestations_last_week = 0 THEN 'N/A'
        ELSE toString(ROUND((tw.attestations_this_week - lw.attestations_last_week) * 100.0 / lw.attestations_last_week, 1)) || '%'
    END as change
FROM this_week tw, last_week lw;

-- =============================================================================
-- TOP PERFORMERS
-- =============================================================================

-- 3. Top 10 most active credentials by attestation volume
SELECT 
    ROW_NUMBER() OVER (ORDER BY COUNT(a.attestation_pda) DESC) as rank,
    c.name as credential_name,
    c.credential_pda,
    c.authority,
    COUNT(DISTINCT s.schema_pda) as schema_count,
    COUNT(a.attestation_pda) as total_attestations,
    COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) as tokenized_attestations
FROM credentials_raw c
LEFT JOIN schemas_raw s ON c.credential_pda = s.credential_pda AND s.instruction_type = 'createSchema'
LEFT JOIN attestations_raw a ON s.schema_pda = a.schema_pda 
    AND a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
WHERE c.instruction_type = 'createCredential'
GROUP BY c.name, c.credential_pda, c.authority
ORDER BY total_attestations DESC
LIMIT 10;

-- 4. Most popular schemas (by attestation count)
SELECT 
    ROW_NUMBER() OVER (ORDER BY COUNT(a.attestation_pda) DESC) as rank,
    s.name as schema_name,
    s.schema_pda,
    LENGTH(s.field_names) as field_count,
    COUNT(a.attestation_pda) as total_attestations,
    COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) as tokenized_count,
    COUNT(DISTINCT a.authority) as unique_issuers,
    MAX(a.timestamp) as last_attestation
FROM schemas_raw s
LEFT JOIN attestations_raw a ON s.schema_pda = a.schema_pda 
    AND a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
WHERE s.instruction_type = 'createSchema'
GROUP BY s.name, s.schema_pda, LENGTH(s.field_names)
ORDER BY total_attestations DESC
LIMIT 10;

-- =============================================================================
-- RECENT ACTIVITY FEED
-- =============================================================================

-- 5. Latest 20 significant events
SELECT 
    timestamp,
    CASE instruction_type
        WHEN 'createCredential' THEN '🏛️ New Credential Created'
        WHEN 'createSchema' THEN '📋 New Schema Created'
        WHEN 'createAttestation' THEN '✅ Attestation Issued'
        WHEN 'createTokenizedAttestation' THEN '🪙 Tokenized Attestation'
        WHEN 'tokenizeSchema' THEN '🔄 Schema Tokenized'
        WHEN 'closeAttestation' THEN '❌ Attestation Closed'
        ELSE instruction_type
    END as event_type,
    CASE instruction_type
        WHEN 'createCredential' THEN credential_pda
        WHEN 'createSchema' THEN schema_pda
        WHEN 'createAttestation' THEN attestation_pda
        WHEN 'createTokenizedAttestation' THEN attestation_pda
        WHEN 'tokenizeSchema' THEN schema_pda
        WHEN 'closeAttestation' THEN attestation_pda
        ELSE 'N/A'
    END as primary_account,
    authority,
    CASE instruction_type
        WHEN 'createCredential' THEN name
        WHEN 'createSchema' THEN name
        WHEN 'createTokenizedAttestation' THEN token_name
        ELSE ''
    END as entity_name
FROM (
    SELECT timestamp, instruction_type, credential_pda, '' as schema_pda, '' as attestation_pda, authority, name, '' as token_name FROM credentials_raw
    UNION ALL
    SELECT timestamp, instruction_type, credential_pda, schema_pda, '' as attestation_pda, authority, name, '' as token_name FROM schemas_raw
    UNION ALL
    SELECT timestamp, instruction_type, credential_pda, schema_pda, attestation_pda, authority, '' as name, token_name FROM attestations_raw
    UNION ALL
    SELECT timestamp, instruction_type, credential_pda, schema_pda, '' as attestation_pda, authority, '' as name, '' as token_name FROM tokenization_raw
) all_events
WHERE instruction_type IN ('createCredential', 'createSchema', 'createAttestation', 'createTokenizedAttestation', 'tokenizeSchema', 'closeAttestation')
ORDER BY timestamp DESC
LIMIT 20;

-- =============================================================================
-- SYSTEM HEALTH
-- =============================================================================

-- 6. Data freshness and system status
SELECT 
    table_name,
    latest_timestamp,
    records_count,
    CASE 
        WHEN latest_timestamp >= now() - INTERVAL 5 MINUTE THEN '🟢 Fresh'
        WHEN latest_timestamp >= now() - INTERVAL 30 MINUTE THEN '🟡 Slightly Stale'  
        ELSE '🔴 Stale'
    END as data_status,
    toUnixTimestamp(now()) - toUnixTimestamp(latest_timestamp) as seconds_behind
FROM (
    SELECT 'Credentials' as table_name, MAX(timestamp) as latest_timestamp, COUNT(*) as records_count FROM credentials_raw
    UNION ALL
    SELECT 'Schemas', MAX(timestamp), COUNT(*) FROM schemas_raw
    UNION ALL
    SELECT 'Attestations', MAX(timestamp), COUNT(*) FROM attestations_raw
    UNION ALL
    SELECT 'Tokenization', MAX(timestamp), COUNT(*) FROM tokenization_raw
    UNION ALL
    SELECT 'Events', MAX(timestamp), COUNT(*) FROM events_raw
) system_status
ORDER BY seconds_behind ASC;
