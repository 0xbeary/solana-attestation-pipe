
import { PortalAbstractStream } from '@sqd-pipes/core'
import { getInstructionDescriptor } from '@subsquid/solana-stream'
import * as attestation from '../../abi/solana_attestation_service'

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
          isCommitted: true,
          transaction: true,
        },
      ],
    })

    return source.pipeThrough(
      new TransformStream({
        transform: ({ blocks }, controller) => {
          console.log(`Processing ${blocks.length} blocks`);
          
          blocks.forEach((block: any) => {
            if (!block.instructions) return;
            
            console.log(`Block ${block.header.number}: ${block.instructions.length} instructions`);
            
            for (const ins of block.instructions) {
              if (ins.programId === attestation.programId) {
                console.log(`Found instruction for program ${attestation.programId}:`);
                console.log(`  - Descriptor: ${getInstructionDescriptor(ins)}`);
                console.log(`  - Data: ${ins.data}`);
                console.log(`  - Accounts: ${JSON.stringify(ins.accounts, null, 2)}`);
              }
            }
          });
          
          // We are only logging, not creating records, so we don't enqueue anything.
          controller.enqueue([]);
        },
      }),
    )
  }
}

