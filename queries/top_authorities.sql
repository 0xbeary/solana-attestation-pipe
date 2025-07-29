-- Top Credential Authorities
-- Authorities with the most credential creation activity
SELECT 
  authority,
  COUNT(*) as total_credentials,
  COUNT(DISTINCT name) as unique_credential_names,
  MIN(timestamp) as first_created,
  MAX(timestamp) as last_created
FROM credentials_raw 
WHERE instruction_type = 'createCredential'
GROUP BY authority
ORDER BY total_credentials DESC
LIMIT 10;
