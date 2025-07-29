-- Schema Performance Analysis
-- Analyzes attestation volume and tokenization rates by schema, revealing which credential types are most successful and adopted.
SELECT 
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
ORDER BY total_attestations DESC;
