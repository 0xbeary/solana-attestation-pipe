import path from 'node:path'
import { NodeClickHouseClient } from '@clickhouse/client/dist/client'
import { ClickhouseState } from '@sqd-pipes/core'
import { IndexerFunction, PipeConfig } from '../main'
import { ensureTables } from '../db/clickhouse'
import { AttestationsStream } from '../streams/attestations'
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

  for await (const attestations of await ds.stream()) {
    await clickhouse.insert({
      table: 'attestations_raw',
      format: 'JSONEachRow',
      values: attestations.map((a) => ({
        slot: a.slot,
        timestamp: a.timestamp,
        credential: a.credential,
        schema: a.schema,
        authority: a.authority,
        claim_json: a.claimData,
        expiry: a.expiry,
      })),
    })

    await ds.ack()
  }
}
