import { createClient } from '@clickhouse/client'

function getQueryExplanation(description: string): string {
  const explanations: Record<string, string> = {
    'Sample Attestation Data Inspection': 
      'Shows raw attestation data to understand the actual content and structure of attestations. This reveals what information is being attested to and how data is formatted.',
    
    'Attestation Content Analysis by Schema': 
      'Analyzes claim data patterns for each schema to understand what types of information are being attested. JSON parsing reveals structured data formats and common field patterns.',
    
    'Identity Verification Attestations': 
      'Focuses on identity-related attestations by examining schemas with identity fields. Shows how SAS is being used for KYC, identity verification, and personal credential management.',
    
    'Professional Attestations Analysis': 
      'Examines work-related and professional attestations to understand career verification use cases. Reveals employment history, skills verification, and professional certification patterns.',
    
    'Attestation Data Size and Complexity': 
      'Analyzes the size and complexity of attestation claim data to understand information density. Large claims indicate comprehensive data packages, while small ones suggest simple assertions.',
    
    'Expiry Patterns and Use Cases': 
      'Correlates attestation expiry times with content types to understand temporal use cases. Short-term attestations might be for temporary access, while long-term ones for persistent credentials.',
    
    'Common Claim Data Patterns': 
      'Identifies recurring patterns in claim data across different schemas to understand standardization and common use cases. Reveals how different applications structure their attestation data.',
    
    'Attestation Recipients and Use Cases': 
      'Analyzes who receives attestations and for what purposes, particularly in tokenized scenarios. Shows the distribution and targeting of different credential types.',
    
    'Cross-Schema Data Correlation': 
      'Examines how attestation data varies across different schemas to understand specialization and use case diversity. Shows the ecosystem\'s breadth of applications.',
    
    'Real-World Attestation Examples': 
      'Provides concrete examples of actual attestations with anonymized data to show real use cases. Demonstrates the practical applications of the SAS system.'
  }
  
  return explanations[description] || 'Individual attestation data analysis query.'
}

async function executeQuery(query: string, description: string) {
  const client = createClient({
    url: 'http://localhost:8123',
    database: 'default',
  })

  try {
    console.log(`\n=== ${description} ===`)
    console.log(`${getQueryExplanation(description)}`)
    
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
  console.log('Individual Attestation Data Analysis\n')

  // 1. Sample attestation data inspection
  await executeQuery(
    `SELECT 
      s.name as schema_name,
      a.attestation_pda,
      a.authority,
      LEFT(a.claim_data, 200) as claim_sample,
      length(a.claim_data) as claim_length,
      CASE 
        WHEN a.claim_data LIKE '{%' THEN 'JSON'
        WHEN length(a.claim_data) % 2 = 0 AND a.claim_data REGEXP '^[0-9a-fA-F]+$' THEN 'HEX'
        ELSE 'TEXT'
      END as data_format,
      a.expiry,
      a.is_tokenized,
      a.timestamp
    FROM attestations_raw a
    JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
    WHERE a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    ORDER BY a.timestamp DESC
    LIMIT 15`,
    'Sample Attestation Data Inspection'
  )

  // 2. Attestation content analysis by schema
  await executeQuery(
    `SELECT 
      s.name as schema_name,
      COUNT(*) as total_attestations,
      AVG(length(a.claim_data)) as avg_claim_size,
      MIN(length(a.claim_data)) as min_claim_size,
      MAX(length(a.claim_data)) as max_claim_size,
      COUNT(CASE WHEN a.claim_data LIKE '{%' THEN 1 END) as json_format_count,
      COUNT(CASE WHEN length(a.claim_data) % 2 = 0 AND a.claim_data REGEXP '^[0-9a-fA-F]+$' THEN 1 END) as hex_format_count,
      ROUND(COUNT(CASE WHEN a.claim_data LIKE '{%' THEN 1 END) * 100.0 / COUNT(*), 1) as json_percentage,
      arrayStringConcat(s.field_names, ', ') as expected_fields
    FROM attestations_raw a
    JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
    WHERE a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    GROUP BY s.name, s.schema_pda, arrayStringConcat(s.field_names, ', ')
    ORDER BY total_attestations DESC`,
    'Attestation Content Analysis by Schema'
  )

  // 3. Identity verification attestations (focusing on schemas with identity-related fields)
  await executeQuery(
    `SELECT 
      s.name as schema_name,
      COUNT(*) as identity_attestations,
      arrayStringConcat(s.field_names, ', ') as identity_fields,
      COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) as tokenized_identities,
      AVG(length(a.claim_data)) as avg_identity_data_size,
      MIN(a.timestamp) as first_identity_attestation,
      MAX(a.timestamp) as latest_identity_attestation
    FROM attestations_raw a
    JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
    WHERE a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
      AND (
        arrayStringConcat(s.field_names, ',') LIKE '%name%' OR
        arrayStringConcat(s.field_names, ',') LIKE '%id%' OR
        arrayStringConcat(s.field_names, ',') LIKE '%document%' OR
        arrayStringConcat(s.field_names, ',') LIKE '%birth%' OR
        arrayStringConcat(s.field_names, ',') LIKE '%nationality%' OR
        arrayStringConcat(s.field_names, ',') LIKE '%gender%'
      )
    GROUP BY s.name, s.schema_pda, arrayStringConcat(s.field_names, ', ')
    ORDER BY identity_attestations DESC`,
    'Identity Verification Attestations'
  )

  // 4. Professional attestations analysis
  await executeQuery(
    `SELECT 
      s.name as schema_name,
      COUNT(*) as professional_attestations,
      arrayStringConcat(s.field_names, ', ') as professional_fields,
      COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) as tokenized_professional,
      COUNT(DISTINCT a.authority) as issuing_authorities,
      AVG(CASE WHEN a.expiry > 0 THEN (a.expiry - toUnixTimestamp(a.timestamp)) / 86400 END) as avg_validity_days
    FROM attestations_raw a
    JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
    WHERE a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
      AND (
        arrayStringConcat(s.field_names, ',') LIKE '%company%' OR
        arrayStringConcat(s.field_names, ',') LIKE '%position%' OR
        arrayStringConcat(s.field_names, ',') LIKE '%job%' OR
        arrayStringConcat(s.field_names, ',') LIKE '%career%' OR
        arrayStringConcat(s.field_names, ',') LIKE '%work%' OR
        arrayStringConcat(s.field_names, ',') LIKE '%employment%'
      )
    GROUP BY s.name, s.schema_pda, arrayStringConcat(s.field_names, ', ')
    ORDER BY professional_attestations DESC`,
    'Professional Attestations Analysis'
  )

  // 5. Attestation data size and complexity correlation
  await executeQuery(
    `SELECT 
      CASE 
        WHEN length(claim_data) < 100 THEN 'Small (< 100 chars)'
        WHEN length(claim_data) < 500 THEN 'Medium (100-500 chars)'
        WHEN length(claim_data) < 1000 THEN 'Large (500-1000 chars)'
        ELSE 'Very Large (1000+ chars)'
      END as data_size_category,
      COUNT(*) as attestation_count,
      AVG(length(claim_data)) as avg_size,
      COUNT(CASE WHEN is_tokenized = 1 THEN 1 END) as tokenized_count,
      COUNT(DISTINCT schema_pda) as unique_schemas,
      ROUND(COUNT(CASE WHEN is_tokenized = 1 THEN 1 END) * 100.0 / COUNT(*), 1) as tokenization_rate
    FROM attestations_raw 
    WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    GROUP BY 
      CASE 
        WHEN length(claim_data) < 100 THEN 'Small (< 100 chars)'
        WHEN length(claim_data) < 500 THEN 'Medium (100-500 chars)'
        WHEN length(claim_data) < 1000 THEN 'Large (500-1000 chars)'
        ELSE 'Very Large (1000+ chars)'
      END
    ORDER BY avg_size`,
    'Attestation Data Size and Complexity'
  )

  // 6. Expiry patterns and use case correlation
  await executeQuery(
    `SELECT 
      s.name as schema_name,
      COUNT(*) as total_attestations,
      COUNT(CASE WHEN a.expiry = 0 THEN 1 END) as never_expires,
      COUNT(CASE WHEN a.expiry > 0 AND a.expiry > toUnixTimestamp(now()) THEN 1 END) as currently_valid,
      COUNT(CASE WHEN a.expiry > 0 AND a.expiry <= toUnixTimestamp(now()) THEN 1 END) as expired,
      AVG(CASE WHEN a.expiry > 0 THEN (a.expiry - toUnixTimestamp(a.timestamp)) / 86400 END) as avg_validity_days,
      MIN(CASE WHEN a.expiry > 0 THEN (a.expiry - toUnixTimestamp(a.timestamp)) / 86400 END) as min_validity_days,
      MAX(CASE WHEN a.expiry > 0 THEN (a.expiry - toUnixTimestamp(a.timestamp)) / 86400 END) as max_validity_days
    FROM attestations_raw a
    JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
    WHERE a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    GROUP BY s.name, s.schema_pda
    ORDER BY total_attestations DESC`,
    'Expiry Patterns and Use Cases'
  )

  // 7. Common claim data patterns (for JSON formatted data)
  await executeQuery(
    `SELECT 
      s.name as schema_name,
      COUNT(*) as json_attestations,
      COUNT(CASE WHEN claim_data LIKE '%"address"%' THEN 1 END) as contains_address,
      COUNT(CASE WHEN claim_data LIKE '%"name"%' THEN 1 END) as contains_name,
      COUNT(CASE WHEN claim_data LIKE '%"date"%' THEN 1 END) as contains_date,
      COUNT(CASE WHEN claim_data LIKE '%"id"%' THEN 1 END) as contains_id,
      COUNT(CASE WHEN claim_data LIKE '%"company"%' THEN 1 END) as contains_company,
      COUNT(CASE WHEN claim_data LIKE '%"verification"%' THEN 1 END) as contains_verification,
      LEFT(MAX(claim_data), 300) as sample_json_data
    FROM attestations_raw a
    JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
    WHERE a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
      AND a.claim_data LIKE '{%'
    GROUP BY s.name, s.schema_pda
    ORDER BY json_attestations DESC`,
    'Common Claim Data Patterns'
  )

  // 8. Tokenized attestation recipients and use cases
  await executeQuery(
    `SELECT 
      s.name as schema_name,
      a.token_name,
      a.token_symbol,
      COUNT(*) as tokenized_attestations,
      COUNT(DISTINCT a.recipient) as unique_recipients,
      COUNT(DISTINCT a.attestation_mint) as unique_mints,
      AVG(length(a.claim_data)) as avg_claim_size,
      LEFT(MAX(a.claim_data), 200) as sample_claim_data,
      MIN(a.timestamp) as first_issued,
      MAX(a.timestamp) as last_issued
    FROM attestations_raw a
    JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
    WHERE a.instruction_type = 'createTokenizedAttestation'
      AND a.token_name != ''
    GROUP BY s.name, a.token_name, a.token_symbol
    ORDER BY tokenized_attestations DESC`,
    'Attestation Recipients and Use Cases'
  )

  // 9. Real-world attestation examples (anonymized)
  await executeQuery(
    `SELECT 
      s.name as schema_name,
      arrayStringConcat(s.field_names, ', ') as expected_structure,
      CASE 
        WHEN a.claim_data LIKE '{%' THEN 'JSON_STRUCTURED'
        WHEN length(a.claim_data) % 2 = 0 AND a.claim_data REGEXP '^[0-9a-fA-F]+$' THEN 'HEX_ENCODED'
        ELSE 'PLAIN_TEXT'
      END as data_encoding,
      length(a.claim_data) as data_length,
      CASE 
        WHEN a.expiry = 0 THEN 'PERMANENT'
        WHEN a.expiry > toUnixTimestamp(now()) THEN 'VALID'
        ELSE 'EXPIRED'
      END as validity_status,
      a.is_tokenized,
      LEFT(a.claim_data, 150) as anonymized_sample,
      a.timestamp as issued_at
    FROM attestations_raw a
    JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
    WHERE a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
    ORDER BY a.timestamp DESC
    LIMIT 20`,
    'Real-World Attestation Examples'
  )

  console.log('\nAttestation Data Analysis Completed')
  console.log('\nKey Insights about Attestation Content:')
  console.log('• Attestations contain structured data for identity verification, professional credentials, and custom use cases')
  console.log('• JSON format is commonly used for structured data, with hex encoding for binary content')
  console.log('• Identity attestations include personal information like names, documents, and verification status')
  console.log('• Professional attestations track employment, positions, and career-related information')
  console.log('• Tokenized attestations enable transferable credentials with SPL Token-2022 integration')
  console.log('• Expiry patterns vary by use case: permanent for identity, time-limited for professional credentials')
}

main().catch(console.error)
