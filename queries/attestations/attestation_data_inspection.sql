-- Sample Attestation Data Inspection
-- Detailed look at individual attestation data formats and content
SELECT 
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
LIMIT 15;
