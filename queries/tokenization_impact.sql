-- Cross-Program Tokenization Impact
-- Measures the effectiveness of schema tokenization by tracking subsequent tokenized attestation creation.
SELECT 
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
ORDER BY tokenized_attestations_created DESC;
