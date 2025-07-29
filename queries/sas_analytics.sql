-- Solana Attestation Service Analytics Queries
-- These queries demonstrate comprehensive analysis of the SAS ecosystem

-- =============================================================================
-- CREDENTIAL ANALYTICS
-- =============================================================================

-- 1. Top credential authorities by volume
SELECT 
    authority,
    COUNT(*) as total_credentials,
    COUNT(DISTINCT name) as unique_credential_names,
    MIN(timestamp) as first_created,
    MAX(timestamp) as last_created
FROM credentials_raw 
WHERE instruction_type = 'createCredential'
GROUP BY authority
ORDER BY total_credentials DESC
LIMIT 20;

-- 2. Credential authority changes over time
SELECT 
    credential_pda,
    authority,
    timestamp,
    arrayStringConcat(signers, ', ') as current_signers,
    arrayStringConcat(previous_signers, ', ') as previous_signers,
    length(signers) as signer_count,
    length(previous_signers) as previous_signer_count
FROM credentials_raw 
WHERE instruction_type = 'changeAuthorizedSigners'
ORDER BY timestamp DESC
LIMIT 50;

-- 3. Multi-signer credential analysis
SELECT 
    length(signers) as signer_count,
    COUNT(*) as credential_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
FROM credentials_raw 
WHERE instruction_type = 'createCredential'
GROUP BY length(signers)
ORDER BY signer_count;

-- =============================================================================
-- SCHEMA ANALYTICS
-- =============================================================================

-- 4. Schema creation and management by credential
SELECT 
    credential_pda,
    COUNT(CASE WHEN instruction_type = 'createSchema' THEN 1 END) as schemas_created,
    COUNT(CASE WHEN instruction_type = 'changeSchemaStatus' THEN 1 END) as status_changes,
    COUNT(CASE WHEN instruction_type = 'changeSchemaDescription' THEN 1 END) as description_changes,
    COUNT(CASE WHEN instruction_type = 'changeSchemaVersion' THEN 1 END) as version_changes,
    MIN(timestamp) as first_schema,
    MAX(timestamp) as last_activity
FROM schemas_raw
GROUP BY credential_pda
ORDER BY schemas_created DESC
LIMIT 20;

-- 5. Schema field complexity analysis
SELECT 
    credential_pda,
    schema_pda,
    name,
    length(field_names) as field_count,
    arrayStringConcat(field_names, ', ') as fields,
    length(layout_buffer) / 2 as layout_size_bytes, -- hex string, so divide by 2
    timestamp as created_at
FROM schemas_raw 
WHERE instruction_type = 'createSchema'
ORDER BY field_count DESC, layout_size_bytes DESC
LIMIT 30;

-- 6. Schema status transitions
SELECT 
    schema_pda,
    credential_pda,
    CASE WHEN is_paused = 1 THEN 'PAUSED' ELSE 'ACTIVE' END as new_status,
    CASE WHEN previous_status = 1 THEN 'PAUSED' ELSE 'ACTIVE' END as old_status,
    timestamp
FROM schemas_raw 
WHERE instruction_type = 'changeSchemaStatus'
ORDER BY timestamp DESC
LIMIT 50;

-- =============================================================================
-- ATTESTATION ANALYTICS
-- =============================================================================

-- 7. Attestation volume by schema and credential
SELECT 
    s.name as schema_name,
    s.credential_pda,
    COUNT(*) as total_attestations,
    COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) as tokenized_count,
    COUNT(CASE WHEN a.is_tokenized = 0 THEN 1 END) as regular_count,
    MIN(a.timestamp) as first_attestation,
    MAX(a.timestamp) as last_attestation,
    AVG(a.expiry) as avg_expiry_timestamp
FROM attestations_raw a
JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
WHERE a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
GROUP BY s.name, s.credential_pda
ORDER BY total_attestations DESC
LIMIT 25;

-- 8. Attestation expiry analysis
SELECT 
    CASE 
        WHEN expiry = 0 THEN 'Never expires'
        WHEN expiry < toUnixTimestamp(now()) THEN 'Expired'
        WHEN expiry < toUnixTimestamp(now() + INTERVAL 30 DAY) THEN 'Expires within 30 days'
        WHEN expiry < toUnixTimestamp(now() + INTERVAL 90 DAY) THEN 'Expires within 90 days'
        ELSE 'Long-term valid'
    END as expiry_status,
    COUNT(*) as attestation_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
FROM attestations_raw 
WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
GROUP BY expiry_status
ORDER BY attestation_count DESC;

-- 9. Closed attestations analysis
SELECT 
    DATE(timestamp) as closure_date,
    COUNT(*) as attestations_closed,
    COUNT(CASE WHEN instruction_type = 'closeAttestation' THEN 1 END) as regular_closed,
    COUNT(CASE WHEN instruction_type = 'closeTokenizedAttestation' THEN 1 END) as tokenized_closed
FROM attestations_raw 
WHERE instruction_type IN ('closeAttestation', 'closeTokenizedAttestation')
GROUP BY DATE(timestamp)
ORDER BY closure_date DESC
LIMIT 30;

-- =============================================================================
-- TOKENIZATION ANALYTICS
-- =============================================================================

-- 10. Tokenization adoption by schema
SELECT 
    t.schema_pda,
    s.name as schema_name,
    s.credential_pda,
    t.max_size,
    COUNT(a.attestation_pda) as tokenized_attestations,
    t.timestamp as tokenization_date
FROM tokenization_raw t
JOIN schemas_raw s ON t.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
LEFT JOIN attestations_raw a ON t.schema_pda = a.schema_pda AND a.is_tokenized = 1
GROUP BY t.schema_pda, s.name, s.credential_pda, t.max_size, t.timestamp
ORDER BY tokenized_attestations DESC, tokenization_date DESC;

-- 11. Token metadata analysis
SELECT 
    token_name,
    token_symbol,
    COUNT(*) as attestation_count,
    COUNT(DISTINCT schema_pda) as unique_schemas,
    COUNT(DISTINCT recipient) as unique_recipients,
    AVG(mint_account_space) as avg_mint_space
FROM attestations_raw 
WHERE instruction_type = 'createTokenizedAttestation'
  AND token_name != ''
GROUP BY token_name, token_symbol
ORDER BY attestation_count DESC
LIMIT 20;

-- =============================================================================
-- TEMPORAL ANALYTICS
-- =============================================================================

-- 12. Daily activity overview
SELECT 
    DATE(timestamp) as date,
    COUNT(CASE WHEN instruction_type = 'createCredential' THEN 1 END) as credentials_created,
    COUNT(CASE WHEN instruction_type = 'createSchema' THEN 1 END) as schemas_created,
    COUNT(CASE WHEN instruction_type = 'createAttestation' THEN 1 END) as attestations_created,
    COUNT(CASE WHEN instruction_type = 'createTokenizedAttestation' THEN 1 END) as tokenized_attestations,
    COUNT(CASE WHEN instruction_type LIKE 'close%' THEN 1 END) as closures,
    COUNT(*) as total_instructions
FROM (
    SELECT timestamp, instruction_type FROM credentials_raw
    UNION ALL
    SELECT timestamp, instruction_type FROM schemas_raw
    UNION ALL
    SELECT timestamp, instruction_type FROM attestations_raw
    UNION ALL
    SELECT timestamp, instruction_type FROM tokenization_raw
    UNION ALL
    SELECT timestamp, instruction_type FROM events_raw
) all_activities
GROUP BY DATE(timestamp)
ORDER BY date DESC
LIMIT 30;

-- 13. Hourly peak activity analysis
SELECT 
    toHour(timestamp) as hour_of_day,
    COUNT(*) as total_instructions,
    AVG(COUNT(*)) OVER() as avg_hourly,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage_of_daily
FROM (
    SELECT timestamp FROM credentials_raw
    UNION ALL
    SELECT timestamp FROM schemas_raw
    UNION ALL
    SELECT timestamp FROM attestations_raw
    UNION ALL
    SELECT timestamp FROM tokenization_raw
    UNION ALL
    SELECT timestamp FROM events_raw
) all_activities
GROUP BY toHour(timestamp)
ORDER BY hour_of_day;

-- =============================================================================
-- RELATIONSHIP ANALYTICS
-- =============================================================================

-- 14. Authority ecosystem mapping
WITH authority_stats AS (
    SELECT 
        authority,
        COUNT(DISTINCT credential_pda) as credentials_controlled,
        COUNT(DISTINCT schema_pda) as schemas_managed,
        COUNT(DISTINCT attestation_pda) as attestations_issued
    FROM (
        SELECT authority, credential_pda, '' as schema_pda, '' as attestation_pda FROM credentials_raw WHERE instruction_type = 'createCredential'
        UNION ALL
        SELECT authority, credential_pda, schema_pda, '' as attestation_pda FROM schemas_raw WHERE instruction_type = 'createSchema'
        UNION ALL
        SELECT authority, credential_pda, schema_pda, attestation_pda FROM attestations_raw WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    ) combined
    GROUP BY authority
)
SELECT 
    authority,
    credentials_controlled,
    schemas_managed,
    attestations_issued,
    schemas_managed * 1.0 / GREATEST(credentials_controlled, 1) as schemas_per_credential,
    attestations_issued * 1.0 / GREATEST(schemas_managed, 1) as attestations_per_schema
FROM authority_stats
WHERE credentials_controlled > 0 OR schemas_managed > 0 OR attestations_issued > 0
ORDER BY attestations_issued DESC, schemas_managed DESC, credentials_controlled DESC
LIMIT 20;

-- 15. Cross-program interaction analysis (tokenization with SPL Token)
SELECT 
    DATE(a.timestamp) as date,
    COUNT(DISTINCT a.attestation_pda) as tokenized_attestations,
    COUNT(DISTINCT a.attestation_mint) as unique_mints,
    COUNT(DISTINCT a.recipient) as unique_recipients,
    COUNT(DISTINCT t.mint_pda) as schemas_tokenized,
    AVG(t.max_size) as avg_max_token_size
FROM attestations_raw a
LEFT JOIN tokenization_raw t ON a.schema_pda = t.schema_pda
WHERE a.instruction_type = 'createTokenizedAttestation'
GROUP BY DATE(a.timestamp)
ORDER BY date DESC
LIMIT 30;

-- =============================================================================
-- DATA QUALITY AND MONITORING
-- =============================================================================

-- 16. Data completeness check
SELECT 
    'credentials' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN credential_pda = '' THEN 1 END) as missing_pda,
    COUNT(CASE WHEN authority = '' THEN 1 END) as missing_authority,
    COUNT(CASE WHEN name = '' THEN 1 END) as missing_name
FROM credentials_raw
UNION ALL
SELECT 
    'schemas' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN schema_pda = '' THEN 1 END) as missing_pda,
    COUNT(CASE WHEN authority = '' THEN 1 END) as missing_authority,
    COUNT(CASE WHEN name = '' THEN 1 END) as missing_name
FROM schemas_raw
UNION ALL
SELECT 
    'attestations' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN attestation_pda = '' THEN 1 END) as missing_pda,
    COUNT(CASE WHEN authority = '' THEN 1 END) as missing_authority,
    COUNT(CASE WHEN claim_data = '' THEN 1 END) as missing_claim_data
FROM attestations_raw;

-- 17. Latest indexing status
SELECT 
    table_name,
    MAX(slot) as latest_slot,
    MAX(timestamp) as latest_timestamp,
    COUNT(*) as total_records,
    COUNT(*) / ((MAX(slot) - MIN(slot) + 1) * 1.0) as records_per_slot
FROM (
    SELECT 'credentials' as table_name, slot, timestamp FROM credentials_raw
    UNION ALL
    SELECT 'schemas' as table_name, slot, timestamp FROM schemas_raw
    UNION ALL
    SELECT 'attestations' as table_name, slot, timestamp FROM attestations_raw
    UNION ALL
    SELECT 'tokenization' as table_name, slot, timestamp FROM tokenization_raw
    UNION ALL
    SELECT 'events' as table_name, slot, timestamp FROM events_raw
) all_data
GROUP BY table_name
ORDER BY latest_slot DESC;
