import { createClient } from '@clickhouse/client'

async function executeQuery(query: string, description: string) {
  const client = createClient({
    url: 'http://localhost:8123',
    database: 'default',
  })

  try {
    console.log(`\n=== ${description} ===`)
    console.log(`Query: ${query.substring(0, 100)}...`)
    
    const result = await client.query({
      query,
      format: 'JSONEachRow',
    })
    
    const data = await result.json()
    console.log('Results:')
    console.table(data.slice(0, 10)) // Show first 10 rows
    
    if (data.length > 10) {
      console.log(`... and ${data.length - 10} more rows`)
    }
    
    return data
  } catch (error) {
    console.error(`Error executing query: ${error}`)
    return null
  } finally {
    await client.close()
  }
}

async function main() {
  console.log('Testing Solana Attestation Service Queries\n')

  // 1. Basic health check - check if tables exist and have data
  await executeQuery(
    `SELECT 
      table_name,
      MAX(slot) as latest_slot,
      MAX(timestamp) as latest_timestamp,
      COUNT(*) as total_records
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
    ORDER BY latest_slot DESC`,
    'Table Status Check'
  )

  // 2. Check if we have any data at all
  await executeQuery(
    `SELECT 
      COUNT(*) as total_instructions,
      COUNT(DISTINCT instruction_type) as unique_instruction_types,
      MIN(timestamp) as earliest_data,
      MAX(timestamp) as latest_data
    FROM (
      SELECT instruction_type, timestamp FROM credentials_raw
      UNION ALL
      SELECT instruction_type, timestamp FROM schemas_raw
      UNION ALL
      SELECT instruction_type, timestamp FROM attestations_raw
      UNION ALL
      SELECT instruction_type, timestamp FROM tokenization_raw
      UNION ALL
      SELECT instruction_type, timestamp FROM events_raw
    ) all_instructions`,
    'Overall Data Summary'
  )

  // 3. Instruction type breakdown
  await executeQuery(
    `SELECT 
      instruction_type,
      COUNT(*) as count,
      COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
    FROM (
      SELECT instruction_type FROM credentials_raw
      UNION ALL
      SELECT instruction_type FROM schemas_raw
      UNION ALL
      SELECT instruction_type FROM attestations_raw
      UNION ALL
      SELECT instruction_type FROM tokenization_raw
      UNION ALL
      SELECT instruction_type FROM events_raw
    ) all_instructions
    GROUP BY instruction_type
    ORDER BY count DESC`,
    'Instruction Type Distribution'
  )

  // 4. Top credential authorities (if we have credential data)
  await executeQuery(
    `SELECT 
      authority,
      COUNT(*) as total_credentials,
      COUNT(DISTINCT name) as unique_credential_names,
      MIN(timestamp) as first_created,
      MAX(timestamp) as last_created
    FROM credentials_raw 
    WHERE instruction_type = 'createCredential'
    GROUP BY authority
    ORDER BY total_credentials DESC
    LIMIT 10`,
    'Top Credential Authorities'
  )

  // 5. Schema complexity analysis (if we have schema data)
  await executeQuery(
    `SELECT 
      name,
      length(field_names) as field_count,
      length(layout_buffer) / 2 as layout_size_bytes,
      arrayStringConcat(field_names, ', ') as fields,
      timestamp as created_at
    FROM schemas_raw 
    WHERE instruction_type = 'createSchema'
    ORDER BY field_count DESC, layout_size_bytes DESC
    LIMIT 10`,
    'Most Complex Schemas'
  )

  // 6. Attestation activity summary (if we have attestation data)
  await executeQuery(
    `SELECT 
      DATE(timestamp) as date,
      COUNT(CASE WHEN instruction_type = 'createAttestation' THEN 1 END) as regular_attestations,
      COUNT(CASE WHEN instruction_type = 'createTokenizedAttestation' THEN 1 END) as tokenized_attestations,
      COUNT(CASE WHEN instruction_type LIKE 'close%' THEN 1 END) as closed_attestations,
      COUNT(*) as total_attestation_instructions
    FROM attestations_raw 
    WHERE timestamp >= now() - INTERVAL 30 DAY
    GROUP BY DATE(timestamp)
    ORDER BY date DESC
    LIMIT 10`,
    'Recent Attestation Activity (Last 30 Days)'
  )

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
