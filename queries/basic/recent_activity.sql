-- Recent Attestation Activity (Last 30 Days)
-- Daily attestation activity breakdown for the past month
SELECT 
  DATE(timestamp) as date,
  COUNT(CASE WHEN instruction_type = 'createAttestation' THEN 1 END) as regular_attestations,
  COUNT(CASE WHEN instruction_type = 'createTokenizedAttestation' THEN 1 END) as tokenized_attestations,
  COUNT(CASE WHEN instruction_type LIKE 'close%' THEN 1 END) as closed_attestations,
  COUNT(*) as total_attestation_instructions
FROM attestations_raw 
WHERE timestamp >= now() - INTERVAL 30 DAY
GROUP BY DATE(timestamp)
ORDER BY date DESC
LIMIT 10;
