-- Common Claim Data Patterns
-- Analysis of JSON-formatted claim data patterns
SELECT 
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
ORDER BY json_attestations DESC;
