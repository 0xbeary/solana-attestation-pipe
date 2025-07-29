-- Tokenized Attestation Analysis
-- Deep dive into tokenized attestation patterns, showing token metadata usage and recipient distribution.
SELECT 
  token_name,
  token_symbol,
  COUNT(*) as attestation_count,
  COUNT(DISTINCT recipient) as unique_recipients,
  COUNT(DISTINCT schema_pda) as schemas_used,
  AVG(mint_account_space) as avg_mint_space,
  MIN(timestamp) as first_tokenized,
  MAX(timestamp) as last_tokenized
FROM attestations_raw 
WHERE instruction_type = 'createTokenizedAttestation'
  AND token_name != ''
GROUP BY token_name, token_symbol
ORDER BY attestation_count DESC;
