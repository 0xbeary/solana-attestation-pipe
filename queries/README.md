# Solana Attestation Service Query Collection

This directory contains comprehensive SQL queries for analyzing the Solana Attestation Service (SAS) data indexed by our pipeline. The queries are organized into different categories based on their use cases.

## Query Files Overview

### `dashboard.sql`
**Quick insights and KPIs for executive dashboards**
- Key performance indicators (total credentials, schemas, attestations)
- Weekly growth trends and comparisons
- Top performing credentials and schemas
- Recent activity feed
- System health monitoring

Perfect for: Executive dashboards, daily standup metrics, high-level overview

### `monitoring.sql`
**Real-time monitoring and operational queries**
- Live instruction stream monitoring
- Current hour activity summary
- Health monitoring and lag detection
- Error detection and anomaly patterns
- Performance metrics and throughput analysis
- Business metrics (success rates, adoption rates)

Perfect for: Operations teams, alerting systems, real-time dashboards

### `sas_analytics.sql`
**Comprehensive analysis of SAS ecosystem**
- Credential authority analytics
- Schema creation and management patterns
- Attestation volume analysis by schema/credential
- Tokenization adoption tracking
- Temporal activity patterns
- Relationship mapping between entities
- Data quality monitoring

Perfect for: Product analytics, business intelligence, research

### `advanced_analytics.sql`
**Deep insights and complex analytical queries**
- Ecosystem growth analysis with cumulative metrics
- Authority network analysis and influence scoring
- Schema evolution and lifecycle patterns
- Tokenization impact analysis
- Temporal pattern recognition (weekly/seasonal)
- Advanced cohort retention analysis

Perfect for: Data science, strategic planning, research reports

## Quick Start Guide

### 1. Basic Health Check
```sql
-- Check if indexer is running and data is fresh
SELECT 
    table_name,
    latest_timestamp,
    records_count,
    toUnixTimestamp(now()) - toUnixTimestamp(latest_timestamp) as seconds_behind
FROM (
    SELECT 'Attestations' as table_name, MAX(timestamp) as latest_timestamp, COUNT(*) as records_count FROM attestations_raw
) system_status;
```

### 2. Current Activity Overview
```sql
-- See what's happening right now
SELECT 
    instruction_type,
    COUNT(*) as count_last_hour
FROM (
    SELECT instruction_type FROM credentials_raw WHERE timestamp >= now() - INTERVAL 1 HOUR
    UNION ALL
    SELECT instruction_type FROM schemas_raw WHERE timestamp >= now() - INTERVAL 1 HOUR
    UNION ALL
    SELECT instruction_type FROM attestations_raw WHERE timestamp >= now() - INTERVAL 1 HOUR
) current_activity
GROUP BY instruction_type
ORDER BY count_last_hour DESC;
```

### 3. Top Performers
```sql
-- Most active schemas by attestation volume
SELECT 
    s.name as schema_name,
    COUNT(a.attestation_pda) as total_attestations,
    COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) as tokenized_count
FROM schemas_raw s
LEFT JOIN attestations_raw a ON s.schema_pda = a.schema_pda 
WHERE s.instruction_type = 'createSchema'
  AND a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
GROUP BY s.name, s.schema_pda
ORDER BY total_attestations DESC
LIMIT 10;
```

## Key Data Tables

### `credentials_raw`
Contains all credential-related instructions (create, modify signers)
- Primary key: `credential_pda`
- Important fields: `authority`, `name`, `signers`, `instruction_type`

### `schemas_raw`
Contains all schema-related instructions (create, modify, status changes)
- Primary key: `schema_pda`
- Important fields: `credential_pda`, `name`, `description`, `field_names`, `layout_buffer`

### `attestations_raw`
Contains all attestation-related instructions (create, close, tokenized)
- Primary key: `attestation_pda`
- Important fields: `schema_pda`, `credential_pda`, `claim_data`, `is_tokenized`

### `tokenization_raw`
Contains schema tokenization events
- Links schemas to their token representations
- Important fields: `schema_pda`, `mint_pda`, `max_size`

### `events_raw`
Contains emitEvent instruction data
- Used for program-specific event logging

## Common Query Patterns

### 1. Hierarchical Queries (Credential → Schema → Attestation)
```sql
SELECT 
    c.name as credential_name,
    s.name as schema_name,
    COUNT(a.attestation_pda) as attestation_count
FROM credentials_raw c
JOIN schemas_raw s ON c.credential_pda = s.credential_pda
JOIN attestations_raw a ON s.schema_pda = a.schema_pda
WHERE c.instruction_type = 'createCredential'
  AND s.instruction_type = 'createSchema'
  AND a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
GROUP BY c.name, s.name;
```

### 2. Time Series Analysis
```sql
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as daily_attestations
FROM attestations_raw 
WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
  AND timestamp >= now() - INTERVAL 30 DAY
GROUP BY DATE(timestamp)
ORDER BY date;
```

### 3. Authority Analysis
```sql
SELECT 
    authority,
    COUNT(DISTINCT credential_pda) as credentials_managed,
    COUNT(DISTINCT schema_pda) as schemas_created,
    COUNT(DISTINCT attestation_pda) as attestations_issued
FROM (
    SELECT authority, credential_pda, '' as schema_pda, '' as attestation_pda FROM credentials_raw
    UNION ALL
    SELECT authority, credential_pda, schema_pda, '' as attestation_pda FROM schemas_raw
    UNION ALL
    SELECT authority, credential_pda, schema_pda, attestation_pda FROM attestations_raw
) authority_activity
GROUP BY authority
ORDER BY attestations_issued DESC;
```

## Performance Tips

1. **Use time filters**: Always filter by timestamp for recent data analysis
2. **Index awareness**: Queries are optimized for the MergeTree ordering (slot-based)
3. **Materialized views**: Use the pre-built summary views for fast aggregations
4. **Batch analysis**: For large datasets, consider using date ranges
5. **Distinct operations**: Be careful with DISTINCT on large result sets

## Monitoring Recommendations

### Set up alerts for:
- Data freshness (no new data for > 5 minutes)
- Unusual activity spikes (> 3 standard deviations)
- Error rates in instruction parsing
- Indexing lag behind latest Solana slot

### Key metrics to track:
- Daily attestation creation rate
- Tokenization adoption percentage
- Average attestations per schema
- Authority engagement levels
- Schema utilization distribution

## Advanced Use Cases

### Research Questions These Queries Can Answer:
1. How does tokenization affect attestation patterns?
2. Which credential authorities are most influential in the ecosystem?
3. What are the common schema evolution patterns?
4. How do network effects influence adoption?
5. What temporal patterns exist in ecosystem activity?

### Business Intelligence Applications:
1. Product adoption tracking
2. User engagement analysis  
3. Feature utilization metrics
4. Growth forecasting
5. Competitive analysis

## Contributing

When adding new queries:
1. Include clear comments explaining the purpose
2. Add example use cases in the header
3. Optimize for performance with appropriate filters
4. Test with realistic data volumes
5. Document any materialized view dependencies

For questions or improvements, please refer to the main project documentation.
