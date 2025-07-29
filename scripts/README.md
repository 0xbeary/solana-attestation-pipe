# Analytics Scripts

This directory contains TypeScript scripts for analyzing Solana Attestation Service data. All scripts use organized SQL queries from the `queries/` directory structure.

## Scripts Overview

### test-queries.ts
**Basic health check and overview analytics**

Uses queries from `queries/basic/` folder for essential system monitoring:
- Table status and record counts (`table_status.sql`)
- Instruction type distribution (`instruction_distribution.sql`) 
- Top credential authorities (`top_authorities.sql`)
- Schema complexity analysis (`complex_schemas.sql`)
- Recent attestation activity (`recent_activity.sql`)
- Overall data summary (`data_summary.sql`)

**Usage:**
```bash
pnpm test-queries
```

**Key Outputs:**
- System health status and data freshness
- Data completeness validation
- Basic ecosystem metrics and authority activity levels

### detailed-analytics.ts
**Deep ecosystem analysis and business intelligence**

Uses queries from `queries/analytics/` and `queries/tokenization/` folders:
- Schema performance analysis (`analytics/schema_performance.sql`)
- Authority influence ranking (`analytics/authority_influence.sql`)
- Schema complexity vs usage (`analytics/schema_complexity.sql`)
- Daily ecosystem activity (`analytics/daily_activity.sql`)
- Attestation closure patterns (`analytics/closure_patterns.sql`)
- Tokenization analysis (`tokenization/tokenized_analysis.sql`)
- Cross-program tokenization impact (`tokenization/tokenization_impact.sql`)

**Usage:**
```bash
pnpm detailed-analytics
```

**Key Outputs:**
- Authority influence scores and ecosystem mapping
- Schema adoption rates and tokenization success
- Growth trends and operational patterns
- SPL Token-2022 integration effectiveness

### attestation-data-analysis.ts
**Individual attestation content and pattern analysis**

Uses queries from `queries/attestations/` and `queries/tokenization/` folders:
- Attestation data inspection (`attestations/attestation_data_inspection.sql`)
- Content analysis by schema (`attestations/content_analysis_by_schema.sql`)
- Identity verification patterns (`attestations/identity_attestations.sql`)
- Professional credentials analysis (`attestations/professional_attestations.sql`)
- Data size complexity (`attestations/data_size_complexity.sql`)
- Expiry patterns (`attestations/expiry_patterns.sql`)
- Claim data patterns (`attestations/claim_data_patterns.sql`)
- Tokenized recipients (`tokenization/tokenized_recipients.sql`)

**Usage:**
```bash
pnpm attestation-analysis
```

**Key Outputs:**
- Real attestation content examples and data formats
- Use case patterns (identity, professional, etc.)
- Content complexity and structure analysis
- Temporal usage characteristics and expiry management
**Comprehensive ecosystem analysis**

Deep-dive analytics for business intelligence and research:
- Schema performance and tokenization rates
- Authority influence ranking
- Schema complexity vs usage correlation
- Daily ecosystem activity timeline
- Attestation closure patterns
- Cross-program tokenization impact

**Usage:**
```bash
pnpm detailed-analytics
```

**Key Outputs:**
- Tokenization adoption metrics
- Authority network analysis
- Schema utilization patterns
- Ecosystem growth trends

### attestation-data-analysis.ts
**Individual attestation content analysis**

Analyzes actual attestation data to understand real-world use cases:
- Attestation content inspection and patterns
- Identity verification use cases
- Professional credential analysis
- Data format and encoding patterns
- Expiry patterns and temporal use cases
- Tokenized attestation recipient analysis
- Real-world examples with anonymized data

**Usage:**
```bash
pnpm attestation-analysis
```

**Key Outputs:**
- What attestations are actually used for
- Common data structures and patterns
- Identity vs professional credential usage
- Data size and complexity analysis
- Real use case examples

## Combined Analytics

```bash
# Run basic health check and ecosystem analysis
pnpm analytics

# Run all analytics including attestation content analysis
pnpm full-analytics
```

## Prerequisites

- ClickHouse database running (via `docker compose up -d`)
- Node.js and TypeScript installed
- Indexed SAS data available

## Customization

Both scripts use a modular query execution function. To add custom analytics:

1. Create a new query in the `executeQuery()` call
2. Add descriptive labels for output clarity
3. Follow the existing error handling patterns

## Output Format

All scripts output results in table format for easy reading. Large result sets are automatically truncated with summary information provided.

## Performance Notes

- Queries are optimized for ClickHouse MergeTree ordering
- Time-based filtering is used where appropriate
- Complex analytics may take longer on large datasets
- Consider using the materialized views for faster aggregations
