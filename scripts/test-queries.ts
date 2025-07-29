import { executeQuery, loadSqlQuery } from './query-utils'

async function main() {
  console.log('Testing Solana Attestation Service Queries\n')

  // 1. Basic health check - check if tables exist and have data
  await executeQuery(loadSqlQuery('table_status.sql', 'basic'), 'Table Status Check')

  // 2. Check if we have any data at all
  await executeQuery(loadSqlQuery('data_summary.sql', 'basic'), 'Overall Data Summary')

  // 3. Instruction type breakdown
  await executeQuery(loadSqlQuery('instruction_distribution.sql', 'basic'), 'Instruction Type Distribution')

  // 4. Top credential authorities (if we have credential data)
  await executeQuery(loadSqlQuery('top_authorities.sql', 'basic'), 'Top Credential Authorities')

  // 5. Schema complexity analysis (if we have schema data)
  await executeQuery(loadSqlQuery('complex_schemas.sql', 'basic'), 'Most Complex Schemas')

  // 6. Attestation activity summary (if we have attestation data)
  await executeQuery(loadSqlQuery('recent_activity.sql', 'basic'), 'Recent Attestation Activity (Last 30 Days)')

  // 7. Authority ecosystem overview
  await executeQuery(
    `WITH authority_stats AS (
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
    LIMIT 10`,
    'Authority Ecosystem Overview'
  )

  // 8. Data freshness check
  await executeQuery(
    `SELECT 
      table_name,
      latest_timestamp,
      records_count,
      toUnixTimestamp(now()) - toUnixTimestamp(latest_timestamp) as seconds_behind,
      CASE 
        WHEN toUnixTimestamp(now()) - toUnixTimestamp(latest_timestamp) > 300 THEN '🔴 Stale'
        WHEN toUnixTimestamp(now()) - toUnixTimestamp(latest_timestamp) > 60 THEN '🟡 Slightly Behind'
        ELSE '🟢 Fresh'
      END as status
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
    ORDER BY seconds_behind ASC`,
    'Data Freshness Status'
  )

  console.log('\nQuery execution completed!')
}

main().catch(console.error)
