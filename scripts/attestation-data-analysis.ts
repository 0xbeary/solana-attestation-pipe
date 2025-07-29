import { executeQuery, loadSqlQuery } from './query-utils'

async function main() {
  console.log('Individual Attestation Data Analysis\n')

  // 1. Sample attestation data inspection
  await executeQuery(loadSqlQuery('attestation_data_inspection.sql'), 'Sample Attestation Data Inspection', false)

  // 2. Attestation content analysis by schema
  await executeQuery(loadSqlQuery('content_analysis_by_schema.sql'), 'Attestation Content Analysis by Schema', false)

  // 3. Identity verification attestations (focusing on schemas with identity-related fields)
  await executeQuery(loadSqlQuery('identity_attestations.sql'), 'Identity Verification Attestations', false)

  // 4. Professional attestations analysis
  await executeQuery(loadSqlQuery('professional_attestations.sql'), 'Professional Attestations Analysis', false)

  // 5. Attestation data size and complexity correlation
  await executeQuery(loadSqlQuery('data_size_complexity.sql'), 'Attestation Data Size and Complexity', false)

  // 6. Expiry patterns and use case correlation
  await executeQuery(loadSqlQuery('expiry_patterns.sql'), 'Expiry Patterns and Use Cases', false)

  // 7. Common claim data patterns (for JSON formatted data)
  await executeQuery(loadSqlQuery('claim_data_patterns.sql'), 'Common Claim Data Patterns', false)

  // 8. Tokenized attestation recipients and use cases
  await executeQuery(loadSqlQuery('tokenized_recipients.sql'), 'Tokenized Attestation Recipients and Use Cases', false)

  console.log('\nAttestation data analysis completed')
  console.log('\nKey Data Insights:')
  console.log('• Real attestation data with diverse formats (JSON, HEX, TEXT)')
  console.log('• Identity verification schemas like "SolidKYC" with 14 detailed fields')
  console.log('• Professional credential patterns with expiry management')
  console.log('• Tokenization enabling SPL Token-2022 integration for credentials')
  console.log('• Complex claim data ranging from simple assertions to comprehensive data packages')
}

main().catch(console.error)
