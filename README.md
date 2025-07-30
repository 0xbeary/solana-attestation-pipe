# Solana Attestation Service Indexer

A comprehensive indexer for the Solana Attestation Service (SAS) ecosystem that captures and processes all 12 instruction types across the complete credential hierarchy: Credentials → Schemas → Attestations.

## Features

- **Complete SAS Coverage**: Indexes all 12 instruction types including credential management, schema operations, attestation lifecycle, and tokenization
- **Hierarchical Data Model**: Preserves relationships between credentials, schemas, and attestations
- **Tokenization Support**: Full support for SPL Token-2022 integration and tokenized attestations
- **Real-time Analytics**: Comprehensive query collection for business intelligence and monitoring
- **Production Ready**: Built with ClickHouse for high-performance analytics

## Quick Start

### Installation and Setup

```bash
# Install dependencies
pnpm install

# Start ClickHouse database
pnpm db-up
# or: docker compose up -d

# Start the indexer
pnpm start
```

### Database Management

```bash
# Start database
pnpm db-up

# Stop database and remove data
pnpm db-down

# Reset database (stop, remove data, and restart)
pnpm db-reset
```

### Legacy Commands

```bash
# Alternative database commands
docker compose up -d      # Start database
docker compose down -v    # Stop and clean database
```

## Data Analysis

The indexer creates 5 specialized tables covering all SAS instruction types:

- `credentials_raw` - Credential creation and management
- `schemas_raw` - Schema definitions and modifications  
- `attestations_raw` - Attestation lifecycle and tokenization
- `tokenization_raw` - Schema tokenization events
- `events_raw` - Program event emissions

### Running Analytics Scripts

Three comprehensive analytics scripts are available in the `scripts/` folder:

```bash
# Basic health check and overview
pnpm test-queries
# or: npx ts-node scripts/test-queries.ts

# Detailed ecosystem analysis  
pnpm detailed-analytics
# or: npx ts-node scripts/detailed-analytics.ts

# Individual attestation data analysis
pnpm attestation-analysis
# or: npx ts-node scripts/attestation-data-analysis.ts

# Run basic and detailed analytics
pnpm analytics

# Run all analytics scripts
pnpm full-analytics
```

### Direct Database Queries

Access ClickHouse directly for custom queries:

```bash
# Get latest attestations
docker exec -it soldexer_clickhouse clickhouse-client --query "SELECT slot, timestamp, credential_pda, schema_pda, authority, claim_data, expiry FROM attestations_raw ORDER BY slot DESC LIMIT 10;"

# Check instruction type distribution
docker exec -it soldexer_clickhouse clickhouse-client --query "SELECT instruction_type, COUNT(*) as count FROM (SELECT instruction_type FROM credentials_raw UNION ALL SELECT instruction_type FROM schemas_raw UNION ALL SELECT instruction_type FROM attestations_raw) GROUP BY instruction_type ORDER BY count DESC;"

# Authority ecosystem overview
docker exec -it soldexer_clickhouse clickhouse-client --query "SELECT authority, COUNT(DISTINCT credential_pda) as credentials, COUNT(DISTINCT schema_pda) as schemas, COUNT(DISTINCT attestation_pda) as attestations FROM (SELECT authority, credential_pda, '' as schema_pda, '' as attestation_pda FROM credentials_raw WHERE instruction_type = 'createCredential' UNION ALL SELECT authority, credential_pda, schema_pda, '' as attestation_pda FROM schemas_raw WHERE instruction_type = 'createSchema' UNION ALL SELECT authority, credential_pda, schema_pda, attestation_pda FROM attestations_raw WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')) combined GROUP BY authority ORDER BY attestations DESC LIMIT 10;"
```

## Query Collection

Comprehensive SQL analytics are organized by category in the `queries/` directory:

### Basic Queries (`queries/basic/`)
- Health checks and overview statistics
- Table status and data summaries
- Instruction distribution analysis

### Analytics Queries (`queries/analytics/`)
- Authority influence ranking
- Schema performance analysis
- Daily ecosystem activity
- Closure pattern analysis

### Attestation Queries (`queries/attestations/`)
- Individual attestation data inspection
- Content analysis by schema
- Identity and professional verification patterns
- Data size and expiry analysis

### Tokenization Queries (`queries/tokenization/`)
- SPL Token-2022 integration analysis
- Tokenized attestation patterns
- Cross-program impact measurement

See `queries/README.md` for detailed documentation and usage examples.

## Supported Instructions

The indexer captures all 12 SAS instruction types:

**Core Management**
- `createCredential` - Establish credential authorities
- `createSchema` - Define attestation data structures
- `changeSchemaStatus` - Manage schema lifecycle

**Schema Modifications**  
- `changeAuthorizedSigners` - Update credential permissions
- `changeSchemaDescription` - Modify schema metadata
- `changeSchemaVersion` - Version control and updates

**Attestation Lifecycle**
- `createAttestation` - Issue standard attestations
- `closeAttestation` - Terminate attestations

**Tokenization**
- `tokenizeSchema` - Create token representations
- `createTokenizedAttestation` - Issue tokenized attestations
- `closeTokenizedAttestation` - Close tokenized attestations

**Events**
- `emitEvent` - Structured event logging

## Architecture

This indexer is designed to be modular and can be combined with other attestation pipes for comprehensive ecosystem analysis. The ClickHouse backend provides high-performance analytics capabilities for real-time monitoring and business intelligence.
