-- Tokenized Attestation Recipients and Use Cases
-- Analysis of tokenized attestation distribution and usage
SELECT 
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
ORDER BY tokenized_attestations DESC;
