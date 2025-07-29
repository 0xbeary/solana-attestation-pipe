-- Advanced Analytics for Solana Attestation Service
-- Complex queries for business intelligence and research

-- =============================================================================
-- ECOSYSTEM GROWTH ANALYSIS
-- =============================================================================

-- 1. Cumulative growth metrics over time
WITH daily_metrics AS (
    SELECT 
        DATE(timestamp) as date,
        COUNT(CASE WHEN instruction_type = 'createCredential' THEN 1 END) as new_credentials,
        COUNT(CASE WHEN instruction_type = 'createSchema' THEN 1 END) as new_schemas,
        COUNT(CASE WHEN instruction_type IN ('createAttestation', 'createTokenizedAttestation') THEN 1 END) as new_attestations
    FROM (
        SELECT timestamp, instruction_type FROM credentials_raw
        UNION ALL
        SELECT timestamp, instruction_type FROM schemas_raw  
        UNION ALL
        SELECT timestamp, instruction_type FROM attestations_raw
    ) all_data
    GROUP BY DATE(timestamp)
    ORDER BY date
)
SELECT 
    date,
    new_credentials,
    new_schemas,
    new_attestations,
    SUM(new_credentials) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING) as cumulative_credentials,
    SUM(new_schemas) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING) as cumulative_schemas,
    SUM(new_attestations) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING) as cumulative_attestations,
    -- Growth rates
    LAG(SUM(new_attestations) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING), 7) OVER (ORDER BY date) as attestations_7d_ago,
    (SUM(new_attestations) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING) - 
     LAG(SUM(new_attestations) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING), 7) OVER (ORDER BY date)) * 100.0 /
     NULLIF(LAG(SUM(new_attestations) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING), 7) OVER (ORDER BY date), 0) as weekly_growth_rate
FROM daily_metrics
ORDER BY date DESC
LIMIT 90;

-- 2. Authority network analysis - identify key players and clusters
WITH authority_relationships AS (
    -- Find authorities that work with the same credentials/schemas
    SELECT 
        a1.authority as authority_1,
        a2.authority as authority_2,
        COUNT(DISTINCT a1.credential_pda) as shared_credentials,
        COUNT(DISTINCT a1.schema_pda) as shared_schemas
    FROM (
        SELECT authority, credential_pda, schema_pda FROM schemas_raw WHERE instruction_type = 'createSchema'
        UNION ALL
        SELECT authority, credential_pda, schema_pda FROM attestations_raw WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    ) a1
    JOIN (
        SELECT authority, credential_pda, schema_pda FROM schemas_raw WHERE instruction_type = 'createSchema'
        UNION ALL
        SELECT authority, credential_pda, schema_pda FROM attestations_raw WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    ) a2 ON (a1.credential_pda = a2.credential_pda OR a1.schema_pda = a2.schema_pda) AND a1.authority != a2.authority
    GROUP BY a1.authority, a2.authority
    HAVING shared_credentials > 0 OR shared_schemas > 0
),
authority_centrality AS (
    SELECT 
        authority_1 as authority,
        COUNT(*) as connection_count,
        SUM(shared_credentials) as total_shared_credentials,
        SUM(shared_schemas) as total_shared_schemas
    FROM authority_relationships
    GROUP BY authority_1
)
SELECT 
    ac.authority,
    ac.connection_count,
    ac.total_shared_credentials,
    ac.total_shared_schemas,
    -- Individual stats
    cred_stats.credentials_created,
    schema_stats.schemas_created,
    att_stats.attestations_created,
    -- Centrality score
    ac.connection_count * LOG(ac.total_shared_credentials + ac.total_shared_schemas + 1) as influence_score
FROM authority_centrality ac
LEFT JOIN (
    SELECT authority, COUNT(*) as credentials_created 
    FROM credentials_raw WHERE instruction_type = 'createCredential' 
    GROUP BY authority
) cred_stats ON ac.authority = cred_stats.authority
LEFT JOIN (
    SELECT authority, COUNT(*) as schemas_created 
    FROM schemas_raw WHERE instruction_type = 'createSchema' 
    GROUP BY authority
) schema_stats ON ac.authority = schema_stats.authority
LEFT JOIN (
    SELECT authority, COUNT(*) as attestations_created 
    FROM attestations_raw WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    GROUP BY authority
) att_stats ON ac.authority = att_stats.authority
ORDER BY influence_score DESC
LIMIT 25;

-- =============================================================================
-- SCHEMA EVOLUTION ANALYSIS
-- =============================================================================

-- 3. Schema lifecycle patterns
WITH schema_events AS (
    SELECT 
        schema_pda,
        credential_pda,
        name,
        'created' as event_type,
        timestamp,
        length(field_names) as field_count,
        length(layout_buffer) / 2 as layout_size
    FROM schemas_raw 
    WHERE instruction_type = 'createSchema'
    
    UNION ALL
    
    SELECT 
        schema_pda,
        credential_pda,
        '',
        'status_changed' as event_type,
        timestamp,
        0,
        0
    FROM schemas_raw 
    WHERE instruction_type = 'changeSchemaStatus'
    
    UNION ALL
    
    SELECT 
        new_schema_pda as schema_pda,
        credential_pda,
        '',
        'version_updated' as event_type,
        timestamp,
        length(field_names) as field_count,
        length(layout_buffer) / 2 as layout_size
    FROM schemas_raw 
    WHERE instruction_type = 'changeSchemaVersion'
),
schema_lifecycle AS (
    SELECT 
        schema_pda,
        credential_pda,
        MAX(CASE WHEN event_type = 'created' THEN name END) as schema_name,
        MIN(CASE WHEN event_type = 'created' THEN timestamp END) as created_at,
        MAX(timestamp) as last_modified,
        COUNT(CASE WHEN event_type = 'status_changed' THEN 1 END) as status_changes,
        COUNT(CASE WHEN event_type = 'version_updated' THEN 1 END) as version_updates,
        MAX(CASE WHEN event_type IN ('created', 'version_updated') THEN field_count END) as current_field_count,
        MAX(CASE WHEN event_type IN ('created', 'version_updated') THEN layout_size END) as current_layout_size
    FROM schema_events
    GROUP BY schema_pda, credential_pda
)
SELECT 
    sl.*,
    att_stats.total_attestations,
    att_stats.tokenized_attestations,
    att_stats.first_attestation,
    att_stats.last_attestation,
    CASE 
        WHEN sl.status_changes = 0 AND sl.version_updates = 0 THEN 'Stable'
        WHEN sl.status_changes > sl.version_updates THEN 'Frequently Paused'
        WHEN sl.version_updates > 0 THEN 'Actively Developed'
        ELSE 'Managed'
    END as lifecycle_pattern
FROM schema_lifecycle sl
LEFT JOIN (
    SELECT 
        schema_pda,
        COUNT(*) as total_attestations,
        COUNT(CASE WHEN is_tokenized = 1 THEN 1 END) as tokenized_attestations,
        MIN(timestamp) as first_attestation,
        MAX(timestamp) as last_attestation
    FROM attestations_raw 
    WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    GROUP BY schema_pda
) att_stats ON sl.schema_pda = att_stats.schema_pda
ORDER BY att_stats.total_attestations DESC NULLS LAST;

-- =============================================================================
-- TOKENIZATION IMPACT ANALYSIS
-- =============================================================================

-- 4. Compare tokenized vs non-tokenized attestation patterns
WITH attestation_patterns AS (
    SELECT 
        schema_pda,
        is_tokenized,
        COUNT(*) as attestation_count,
        COUNT(DISTINCT authority) as unique_authorities,
        COUNT(DISTINCT recipient) as unique_recipients,
        AVG(CASE WHEN expiry > 0 THEN expiry - toUnixTimestamp(timestamp) END) as avg_validity_period,
        MIN(timestamp) as first_attestation,
        MAX(timestamp) as last_attestation
    FROM attestations_raw 
    WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    GROUP BY schema_pda, is_tokenized
),
schema_comparison AS (
    SELECT 
        schema_pda,
        MAX(CASE WHEN is_tokenized = 0 THEN attestation_count END) as regular_count,
        MAX(CASE WHEN is_tokenized = 1 THEN attestation_count END) as tokenized_count,
        MAX(CASE WHEN is_tokenized = 0 THEN unique_authorities END) as regular_authorities,
        MAX(CASE WHEN is_tokenized = 1 THEN unique_authorities END) as tokenized_authorities,
        MAX(CASE WHEN is_tokenized = 0 THEN avg_validity_period END) as regular_avg_validity,
        MAX(CASE WHEN is_tokenized = 1 THEN avg_validity_period END) as tokenized_avg_validity
    FROM attestation_patterns
    GROUP BY schema_pda
    HAVING regular_count > 0 AND tokenized_count > 0  -- Only schemas with both types
)
SELECT 
    sc.*,
    s.name as schema_name,
    s.credential_pda,
    -- Calculate ratios and differences
    tokenized_count * 100.0 / (regular_count + tokenized_count) as tokenization_rate,
    tokenized_authorities * 100.0 / GREATEST(regular_authorities, 1) as authority_expansion_rate,
    tokenized_avg_validity - regular_avg_validity as validity_period_diff_seconds
FROM schema_comparison sc
JOIN schemas_raw s ON sc.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
ORDER BY tokenized_count DESC;

-- =============================================================================
-- TEMPORAL PATTERN ANALYSIS
-- =============================================================================

-- 5. Identify weekly and seasonal patterns
WITH hourly_activity AS (
    SELECT 
        toDayOfWeek(timestamp) as day_of_week,  -- 1=Monday, 7=Sunday
        toHour(timestamp) as hour_of_day,
        instruction_type,
        COUNT(*) as activity_count
    FROM (
        SELECT timestamp, instruction_type FROM credentials_raw
        UNION ALL
        SELECT timestamp, instruction_type FROM schemas_raw
        UNION ALL
        SELECT timestamp, instruction_type FROM attestations_raw
        UNION ALL
        SELECT timestamp, instruction_type FROM tokenization_raw
    ) all_data
    WHERE timestamp >= now() - INTERVAL 30 DAY  -- Last 30 days for pattern analysis
    GROUP BY day_of_week, hour_of_day, instruction_type
),
pattern_analysis AS (
    SELECT 
        day_of_week,
        hour_of_day,
        SUM(activity_count) as total_activity,
        SUM(CASE WHEN instruction_type IN ('createAttestation', 'createTokenizedAttestation') THEN activity_count END) as attestation_activity,
        -- Calculate z-score for anomaly detection
        (SUM(activity_count) - AVG(SUM(activity_count)) OVER ()) / 
        NULLIF(stddevPop(SUM(activity_count)) OVER (), 0) as activity_zscore
    FROM hourly_activity
    GROUP BY day_of_week, hour_of_day
)
SELECT 
    CASE day_of_week
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday' 
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
        WHEN 7 THEN 'Sunday'
    END as day_name,
    hour_of_day,
    total_activity,
    attestation_activity,
    attestation_activity * 100.0 / NULLIF(total_activity, 0) as attestation_percentage,
    CASE 
        WHEN activity_zscore > 2 THEN 'High Activity'
        WHEN activity_zscore < -1 THEN 'Low Activity'
        ELSE 'Normal Activity'
    END as activity_level
FROM pattern_analysis
ORDER BY day_of_week, hour_of_day;

-- =============================================================================
-- ADVANCED COHORT ANALYSIS
-- =============================================================================

-- 6. Authority cohort retention analysis
WITH authority_first_activity AS (
    SELECT 
        authority,
        MIN(DATE(timestamp)) as first_active_date,
        DATE_TRUNC('month', MIN(timestamp)) as cohort_month
    FROM (
        SELECT authority, timestamp FROM credentials_raw
        UNION ALL
        SELECT authority, timestamp FROM schemas_raw
        UNION ALL
        SELECT authority, timestamp FROM attestations_raw
    ) all_activity
    GROUP BY authority
),
monthly_activity AS (
    SELECT 
        authority,
        DATE_TRUNC('month', timestamp) as activity_month
    FROM (
        SELECT authority, timestamp FROM credentials_raw
        UNION ALL
        SELECT authority, timestamp FROM schemas_raw
        UNION ALL
        SELECT authority, timestamp FROM attestations_raw
    ) all_activity
    GROUP BY authority, DATE_TRUNC('month', timestamp)
),
cohort_retention AS (
    SELECT 
        afa.cohort_month,
        ma.activity_month,
        COUNT(DISTINCT afa.authority) as cohort_size,
        COUNT(DISTINCT ma.authority) as active_authorities,
        dateDiff('month', afa.cohort_month, ma.activity_month) as months_since_first
    FROM authority_first_activity afa
    LEFT JOIN monthly_activity ma ON afa.authority = ma.authority
    WHERE ma.activity_month >= afa.cohort_month
    GROUP BY afa.cohort_month, ma.activity_month
)
SELECT 
    cohort_month,
    months_since_first,
    cohort_size,
    active_authorities,
    active_authorities * 100.0 / cohort_size as retention_rate
FROM cohort_retention
WHERE cohort_month >= now() - INTERVAL 12 MONTH
ORDER BY cohort_month, months_since_first;
