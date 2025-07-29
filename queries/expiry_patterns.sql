-- Expiry Patterns and Use Cases
-- Analysis of attestation expiration patterns
SELECT 
  s.name as schema_name,
  COUNT(*) as total_attestations,
  COUNT(CASE WHEN a.expiry = 0 THEN 1 END) as never_expires,
  COUNT(CASE WHEN a.expiry > 0 AND a.expiry > toUnixTimestamp(now()) THEN 1 END) as currently_valid,
  COUNT(CASE WHEN a.expiry > 0 AND a.expiry <= toUnixTimestamp(now()) THEN 1 END) as expired,
  AVG(CASE WHEN a.expiry > 0 THEN (a.expiry - toUnixTimestamp(a.timestamp)) / 86400 END) as avg_validity_days,
  MIN(CASE WHEN a.expiry > 0 THEN (a.expiry - toUnixTimestamp(a.timestamp)) / 86400 END) as min_validity_days,
  MAX(CASE WHEN a.expiry > 0 THEN (a.expiry - toUnixTimestamp(a.timestamp)) / 86400 END) as max_validity_days
FROM attestations_raw a
JOIN schemas_raw s ON a.schema_pda = s.schema_pda AND s.instruction_type = 'createSchema'
WHERE a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
GROUP BY s.name, s.schema_pda
ORDER BY total_attestations DESC;
