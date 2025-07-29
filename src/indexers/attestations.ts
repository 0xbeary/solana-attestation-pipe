import path from 'node:path'
import { NodeClickHouseClient } from '@clickhouse/client/dist/client'
import { ClickhouseState } from '@sqd-pipes/core'
import { IndexerFunction, PipeConfig } from '../main'
import { ensureTables } from '../db/clickhouse'
import { AttestationsStream, SASRecord, CredentialRecord, SchemaRecord, AttestationRecord, TokenizationRecord, EventRecord } from '../streams/attestations'
import { logger } from '../utils/logger'

export const attestationIndexer: IndexerFunction = async (
  portalUrl: string,
  clickhouse: NodeClickHouseClient,
  config: PipeConfig,
) => {
  const ds = new AttestationsStream({
    portal: `${portalUrl}/datasets/solana-mainnet`,
    blockRange: {
      from: config.fromBlock,
      to: config.toBlock,
    },
    state: new ClickhouseState(clickhouse, {
      table: 'solana_sync_status',
      id: 'solana_attestations',
    }),
    logger,
  })

  await ensureTables(clickhouse, path.join(__dirname, '../db/sql/attestations.sql'))

  for await (const records of await ds.stream()) {
    // Group records by type for efficient batch insertion
    const credentialRecords: CredentialRecord[] = []
    const schemaRecords: SchemaRecord[] = []
    const attestationRecords: AttestationRecord[] = []
    const tokenizationRecords: TokenizationRecord[] = []
    const eventRecords: EventRecord[] = []

    for (const record of records) {
      switch (record.instructionType) {
        case 'createCredential':
        case 'changeAuthorizedSigners':
          credentialRecords.push(record as CredentialRecord)
          break
          
        case 'createSchema':
        case 'changeSchemaStatus':
        case 'changeSchemaDescription':
        case 'changeSchemaVersion':
          schemaRecords.push(record as SchemaRecord)
          break
          
        case 'createAttestation':
        case 'createTokenizedAttestation':
        case 'closeAttestation':
        case 'closeTokenizedAttestation':
          attestationRecords.push(record as AttestationRecord)
          break
          
        case 'tokenizeSchema':
          tokenizationRecords.push(record as TokenizationRecord)
          break
          
        case 'emitEvent':
          eventRecords.push(record as EventRecord)
          break
      }
    }

    // Insert credential records
    if (credentialRecords.length > 0) {
      await clickhouse.insert({
        table: 'credentials_raw',
        format: 'JSONEachRow',
        values: credentialRecords.map((r) => ({
          slot: r.slot,
          timestamp: r.timestamp,
          instruction_type: r.instructionType,
          transaction_hash: r.transactionHash,
          credential_pda: r.credentialPda,
          authority: r.authority,
          name: r.name,
          signers: r.signers,
          previous_signers: r.previousSigners || [],
        })),
      })
    }

    // Insert schema records
    if (schemaRecords.length > 0) {
      await clickhouse.insert({
        table: 'schemas_raw',
        format: 'JSONEachRow',
        values: schemaRecords.map((r) => ({
          slot: r.slot,
          timestamp: r.timestamp,
          instruction_type: r.instructionType,
          transaction_hash: r.transactionHash,
          schema_pda: r.schemaPda,
          credential_pda: r.credentialPda,
          authority: r.authority,
          name: r.name,
          description: r.description,
          previous_description: r.previousDescription || '',
          layout_buffer: r.layoutBuffer,
          field_names: r.fieldNames,
          is_paused: r.isPaused ? 1 : 0,
          previous_status: r.previousStatus ? 1 : 0,
          existing_schema_pda: r.existingSchemaPda || '',
          new_schema_pda: r.newSchemaPda || '',
        })),
      })
    }

    // Insert attestation records
    if (attestationRecords.length > 0) {
      await clickhouse.insert({
        table: 'attestations_raw',
        format: 'JSONEachRow',
        values: attestationRecords.map((r) => ({
          slot: r.slot,
          timestamp: r.timestamp,
          instruction_type: r.instructionType,
          transaction_hash: r.transactionHash,
          attestation_pda: r.attestationPda,
          credential_pda: r.credentialPda,
          schema_pda: r.schemaPda,
          authority: r.authority,
          nonce: r.nonce || '',
          claim_data: r.claimData,
          expiry: r.expiry || 0,
          is_tokenized: r.isTokenized ? 1 : 0,
          token_name: r.tokenName || '',
          token_uri: r.tokenUri || '',
          token_symbol: r.tokenSymbol || '',
          mint_account_space: r.mintAccountSpace || 0,
          attestation_mint: r.attestationMint || '',
          schema_mint: r.schemaMint || '',
          recipient: r.recipient || '',
          recipient_token_account: r.recipientTokenAccount || '',
        })),
      })
    }

    // Insert tokenization records
    if (tokenizationRecords.length > 0) {
      await clickhouse.insert({
        table: 'tokenization_raw',
        format: 'JSONEachRow',
        values: tokenizationRecords.map((r) => ({
          slot: r.slot,
          timestamp: r.timestamp,
          instruction_type: r.instructionType,
          transaction_hash: r.transactionHash,
          schema_pda: r.schemaPda,
          credential_pda: r.credentialPda,
          authority: r.authority,
          mint_pda: r.mintPda,
          max_size: r.maxSize,
          sas_pda: r.sasPda,
        })),
      })
    }

    // Insert event records
    if (eventRecords.length > 0) {
      await clickhouse.insert({
        table: 'events_raw',
        format: 'JSONEachRow',
        values: eventRecords.map((r) => ({
          slot: r.slot,
          timestamp: r.timestamp,
          instruction_type: r.instructionType,
          transaction_hash: r.transactionHash,
          event_authority: r.eventAuthority,
          event_data: r.eventData || '',
        })),
      })
    }

    await ds.ack()
  }
}
