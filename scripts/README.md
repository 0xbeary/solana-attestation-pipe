# Analytics Scripts

This directory contains TypeScript scripts for analyzing Solana Attestation Service data.

## Scripts Overview

### test-queries.ts
**Basic health check and overview analytics**

Provides essential system monitoring and data validation:
- Table status and record counts
- Instruction type distribution
- Top credential authorities
- Schema complexity analysis
- Recent attestation activity
- Authority ecosystem mapping
- Data freshness monitoring

**Usage:**
```bash
pnpm test-queries
```

**Key Outputs:**
- System health status
- Data completeness validation
- Basic ecosystem metrics
- Authority activity levels

### detailed-analytics.ts
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
