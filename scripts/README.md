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
npx ts-node scripts/test-queries.ts
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
npx ts-node scripts/detailed-analytics.ts
```

**Key Outputs:**
- Tokenization adoption metrics
- Authority network analysis
- Schema utilization patterns
- Ecosystem growth trends

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
