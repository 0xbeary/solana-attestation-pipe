-- Identity Verification Attestations
-- Focus on schemas with identity-related fields
SELECT 
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
ORDER BY identity_attestations DESC;
