-- Attestation Closure Patterns
-- Analyzes attestation closure behavior, comparing regular vs tokenized closure rates.
SELECT 
  DATE(timestamp) as closure_date,
  COUNT(*) as attestations_closed,
  COUNT(CASE WHEN instruction_type = 'closeAttestation' THEN 1 END) as regular_closed,
  COUNT(CASE WHEN instruction_type = 'closeTokenizedAttestation' THEN 1 END) as tokenized_closed,
  ROUND(COUNT(CASE WHEN instruction_type = 'closeTokenizedAttestation' THEN 1 END) * 100.0 / COUNT(*), 1) as tokenized_closure_rate
FROM attestations_raw 
WHERE instruction_type IN ('closeAttestation', 'closeTokenizedAttestation')
GROUP BY DATE(timestamp)
ORDER BY closure_date DESC;
