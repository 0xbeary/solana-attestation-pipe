-- Professional Attestations Analysis
-- Focus on work/employment-related attestations
SELECT 
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
ORDER BY professional_attestations DESC;
