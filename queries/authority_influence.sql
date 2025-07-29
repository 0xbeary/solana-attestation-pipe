-- Authority Influence Ranking
-- Calculates authority influence scores based on credential control, schema management, and attestation volume.
WITH authority_stats AS (
  SELECT 
    authority,
    COUNT(DISTINCT credential_pda) as credentials_controlled,
    COUNT(DISTINCT schema_pda) as schemas_managed,
    COUNT(DISTINCT attestation_pda) as attestations_issued
  FROM (
    SELECT authority, credential_pda, '' as schema_pda, '' as attestation_pda FROM credentials_raw WHERE instruction_type = 'createCredential'
    UNION ALL
    SELECT authority, credential_pda, schema_pda, '' as attestation_pda FROM schemas_raw WHERE instruction_type = 'createSchema'
    UNION ALL
    SELECT authority, credential_pda, schema_pda, attestation_pda FROM attestations_raw WHERE instruction_type IN ('createAttestation', 'createTokenizedAttestation')
  ) combined
  GROUP BY authority
)
SELECT 
  authority,
  credentials_controlled,
  schemas_managed,
  attestations_issued,
  ROUND(schemas_managed * 1.0 / GREATEST(credentials_controlled, 1), 2) as schemas_per_credential,
  ROUND(attestations_issued * 1.0 / GREATEST(schemas_managed, 1), 2) as attestations_per_schema,
  -- Calculate influence score
  ROUND(credentials_controlled * LOG(schemas_managed + 1) * LOG(attestations_issued + 1), 2) as influence_score
FROM authority_stats
WHERE credentials_controlled > 0 OR schemas_managed > 0 OR attestations_issued > 0
ORDER BY influence_score DESC;
