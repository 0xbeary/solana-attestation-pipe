-- Attestation Data Size and Complexity
-- Categorize attestations by data size and analyze patterns
SELECT 
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
ORDER BY avg_size;
