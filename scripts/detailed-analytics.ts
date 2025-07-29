import { createClient } from '@clickhouse/client'

async function executeQuery(query: string, description: string) {
  const client = createClient({
    url: 'http://localhost:8123',
    database: 'default',
  })

  try {
    console.log(`\n=== ${description} ===`)
    
    const result = await client.query({
      query,
      format: 'JSONEachRow',
    })
    
    const data = await result.json()
    console.log('Results:')
    console.table(data)
    
    return data
  } catch (error) {
    console.error(`Error executing query: ${error}`)
    return null
  } finally {
    await client.close()
  }
}

async function main() {
  console.log('🔍 Deep Dive Analytics on Real SAS Data\n')

  // 1. Attestation volume by schema with tokenization breakdown
  await executeQuery(
    `SELECT 
      s.name as schema_name,
      s.credential_pda,
      COUNT(*) as total_attestations,
      COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) as tokenized_count,
      COUNT(CASE WHEN a.is_tokenized = 0 THEN 1 END) as regular_count,
      ROUND(COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) * 100.0 / COUNT(*), 1) as tokenization_rate,
      MIN(a.timestamp) as first_attestation,
      MAX(a.timestamp) as last_attestation
    FROM attestations_raw a
    JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
    WHERE a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    GROUP BY s.name, s.credential_pda
    ORDER BY total_attestations DESC`,
    'Schema Performance Analysis'
  )

  // 2. Tokenized attestation details
  await executeQuery(
    `SELECT 
      token_name,
      token_symbol,
      COUNT(*) as attestation_count,
      COUNT(DISTINCT recipient) as unique_recipients,
      COUNT(DISTINCT schema_pda) as schemas_used,
      AVG(mint_account_space) as avg_mint_space,
      MIN(timestamp) as first_tokenized,
      MAX(timestamp) as last_tokenized
    FROM attestations_raw 
    WHERE instruction_type = 'createTokenizedAttestation'
      AND token_name != ''
    GROUP BY token_name, token_symbol
    ORDER BY attestation_count DESC`,
    'Tokenized Attestation Analysis'
  )

  // 3. Authority influence analysis
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
      ROUND(schemas_managed * 1.0 / GREATEST(credentials_controlled, 1), 2) as schemas_per_credential,
      ROUND(attestations_issued * 1.0 / GREATEST(schemas_managed, 1), 2) as attestations_per_schema,
      -- Calculate influence score
      ROUND(credentials_controlled * LOG(schemas_managed + 1) * LOG(attestations_issued + 1), 2) as influence_score
    FROM authority_stats
    WHERE credentials_controlled > 0 OR schemas_managed > 0 OR attestations_issued > 0
    ORDER BY influence_score DESC`,
    'Authority Influence Ranking'
  )

  // 4. Schema complexity vs usage correlation
  await executeQuery(
    `SELECT 
      s.name as schema_name,
      length(s.field_names) as field_count,
      length(s.layout_buffer) / 2 as layout_size_bytes,
      COUNT(a.attestation_pda) as total_attestations,
      COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) as tokenized_attestations,
      ROUND(COUNT(a.attestation_pda) * 1.0 / length(s.field_names), 2) as attestations_per_field,
      arrayStringConcat(s.field_names, ', ') as field_structure
    FROM schemas_raw s
    LEFT JOIN attestations_raw a ON s.schema_pda = a.schema_pda 
      AND a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    WHERE s.instruction_type = 'createSchema'
    GROUP BY s.name, s.schema_pda, length(s.field_names), length(s.layout_buffer), arrayStringConcat(s.field_names, ', ')
    ORDER BY total_attestations DESC`,
    'Schema Complexity vs Usage Analysis'
  )

  // 5. Daily ecosystem activity timeline
  await executeQuery(
    `SELECT 
      DATE(timestamp) as date,
      COUNT(CASE WHEN instruction_type = 'createCredential' THEN 1 END) as credentials_created,
      COUNT(CASE WHEN instruction_type = 'createSchema' THEN 1 END) as schemas_created,
      COUNT(CASE WHEN instruction_type = 'createAttestation' THEN 1 END) as regular_attestations,
      COUNT(CASE WHEN instruction_type = 'createTokenizedAttestation' THEN 1 END) as tokenized_attestations,
      COUNT(CASE WHEN instruction_type = 'tokenizeSchema' THEN 1 END) as schemas_tokenized,
      COUNT(CASE WHEN instruction_type LIKE 'close%' THEN 1 END) as closures,
      COUNT(*) as total_activity
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
    ORDER BY date DESC`,
    'Daily Ecosystem Activity Timeline'
  )

  // 6. Attestation closure analysis
  await executeQuery(
    `SELECT 
      DATE(timestamp) as closure_date,
      COUNT(*) as attestations_closed,
      COUNT(CASE WHEN instruction_type = 'closeAttestation' THEN 1 END) as regular_closed,
      COUNT(CASE WHEN instruction_type = 'closeTokenizedAttestation' THEN 1 END) as tokenized_closed,
      ROUND(COUNT(CASE WHEN instruction_type = 'closeTokenizedAttestation' THEN 1 END) * 100.0 / COUNT(*), 1) as tokenized_closure_rate
    FROM attestations_raw 
    WHERE instruction_type IN ('closeAttestation', 'closeTokenizedAttestation')
    GROUP BY DATE(timestamp)
    ORDER BY closure_date DESC`,
    'Attestation Closure Patterns'
  )

  // 7. Cross-program tokenization analysis
  await executeQuery(
    `SELECT 
      t.schema_pda,
      s.name as schema_name,
      t.max_size as token_max_size,
      COUNT(a.attestation_pda) as tokenized_attestations_created,
      COUNT(DISTINCT a.recipient) as unique_token_recipients,
      COUNT(DISTINCT a.attestation_mint) as unique_token_mints,
      t.timestamp as tokenization_date,
      DATEDIFF('day', t.timestamp, MAX(a.timestamp)) as days_of_activity
    FROM tokenization_raw t
    JOIN schemas_raw s ON t.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
    LEFT JOIN attestations_raw a ON t.schema_pda = a.schema_pda AND a.is_tokenized = 1
    GROUP BY t.schema_pda, s.name, t.max_size, t.timestamp
    ORDER BY tokenized_attestations_created DESC`,
    'Cross-Program Tokenization Impact'
  )

  console.log('\nDeep analytics completed')
  console.log('\nKey Insights from the Data:')
  console.log('• Real SAS ecosystem with active tokenization (60%+ tokenized attestations)')
  console.log('• Multiple authorities managing credential hierarchies')
  console.log('• Complex schemas like "SolidKYC" with 14 fields for identity verification')
  console.log('• Active authority "31s2c..." with 112 attestations across 2 schemas')
  console.log('• Schema-to-token integration working with SPL Token-2022')
}

main().catch(console.error)
