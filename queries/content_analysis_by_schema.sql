-- Attestation Content Analysis by Schema
-- Analysis of claim data formats and sizes by schema
SELECT 
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
ORDER BY total_attestations DESC;
