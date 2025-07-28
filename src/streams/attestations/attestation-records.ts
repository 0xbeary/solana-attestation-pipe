
import { PortalAbstractStream } from '@sqd-pipes/core'
import { getInstructionDescriptor } from '@subsquid/solana-stream'
import * as attestation from '../../abi/solana_attestation_service'
import { Buffer } from 'buffer'

export interface AttestationRecord {
  slot: number;
  timestamp: Date;
  credential: string;
  schema: string;
  authority: string;
  claimData: string;
  expiry: number;
}


export class AttestationsStream extends PortalAbstractStream<AttestationRecord> {
  async stream(): Promise<ReadableStream<AttestationRecord[]>> {
    const source = await this.getStream({
      type: 'solana',
      fields: {
        block: {
          number: true,
          hash: true,
          timestamp: true,
        },
        transaction: {
          transactionIndex: true,
          signatures: true,
        },
        instruction: {
          transactionIndex: true,
          data: true,
          instructionAddress: true,
          programId: true,
          accounts: true,
        },
      },
      instructions: [
        {
          programId: [attestation.programId],
          d1: [attestation.instructions.createAttestation.d1],
          isCommitted: true,
          transaction: true,
        },
      ],
    })

    return source.pipeThrough(
      new TransformStream({
        transform: ({ blocks }, controller) => {
          const records: AttestationRecord[] = []

          blocks.forEach((block: any) => {
            if (!block.instructions) return

            for (const ins of block.instructions) {
              const descriptor = getInstructionDescriptor(ins)
              const firstByte = descriptor.slice(0, 4) // Get first byte as "0x06" format
              
              // console.log('Instruction discriminator:', descriptor)
              // console.log('First byte:', firstByte)
              // console.log('Available instructions:')
              // console.log('  createCredential.d1:', attestation.instructions.createCredential.d1)
              // console.log('  createSchema.d1:', attestation.instructions.createSchema.d1)
              // console.log('  createAttestation.d1:', attestation.instructions.createAttestation.d1)
              // console.log('  createTokenizedAttestation.d1:', attestation.instructions.createTokenizedAttestation.d1)
              // console.log('  closeAttestation.d1:', attestation.instructions.closeAttestation.d1)
              
              // Check which instruction this matches
              // if (firstByte === attestation.instructions.createCredential.d1) {
              //   console.log('→ This is a createCredential instruction')
              // } else if (firstByte === attestation.instructions.createSchema.d1) {
              //   console.log('→ This is a createSchema instruction')
              // } else if (firstByte === attestation.instructions.createAttestation.d1) {
              //   console.log('→ This is a createAttestation instruction')
              // } else if (firstByte === attestation.instructions.createTokenizedAttestation.d1) {
              //   console.log('→ This is a createTokenizedAttestation instruction')
              // } else if (firstByte === attestation.instructions.closeAttestation.d1) {
              //   console.log('→ This is a closeAttestation instruction')
              // } else {
              //   console.log('→ Unknown instruction type')
              // }

              if (
                ins.programId !== attestation.programId ||
                firstByte !== attestation.instructions.createAttestation.d1
              ) {
                continue
              }

              const decoded = attestation.instructions.createAttestation.decode(ins)

              const record = {
                slot: block.header.number,
                timestamp: new Date(block.header.timestamp * 1000),
                credential: decoded.accounts.credential,
                schema: decoded.accounts.schema,
                authority: decoded.accounts.authority,
                claimData: Buffer.from(decoded.data.data).toString(),
                expiry: Number(decoded.data.expiry),
              }

              records.push(record)
            }
          })

          controller.enqueue(records)
        },
      }),
    )
  }
}

