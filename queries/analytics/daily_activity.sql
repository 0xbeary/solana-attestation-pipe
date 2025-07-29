-- Daily Ecosystem Activity Timeline
-- Tracks daily activity across all SAS instruction types to identify growth trends and usage patterns.
SELECT 
  DATE(timestamp) as date,
  COUNT(CASE WHEN instruction_type = 'createCredential' THEN 1 END) as credentials_created,
  COUNT(CASE WHEN instruction_type = 'createSchema' THEN 1 END) as schemas_created,
  COUNT(CASE WHEN instruction_type = 'createAttestation' THEN 1 END) as regular_attestations,
  COUNT(CASE WHEN instruction_type = 'createTokenizedAttestation' THEN 1 END) as tokenized_attestations,
  COUNT(CASE WHEN instruction_type = 'tokenizeSchema' THEN 1 END) as schemas_tokenized,
  COUNT(CASE WHEN instruction_type LIKE 'close%' THEN 1 END) as closures,
  COUNT(*) as total_activity
FROM (
  SELECT timestamp, instruction_type FROM credentials_raw
  UNION ALL
  SELECT timestamp, instruction_type FROM schemas_raw
  UNION ALL
  SELECT timestamp, instruction_type FROM attestations_raw
  UNION ALL
  SELECT timestamp, instruction_type FROM tokenization_raw
  UNION ALL
  SELECT timestamp, instruction_type FROM events_raw
) all_activities
GROUP BY DATE(timestamp)
ORDER BY date DESC;
