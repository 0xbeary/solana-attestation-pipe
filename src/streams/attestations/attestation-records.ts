
import { PortalAbstractStream } from '@sqd-pipes/core'
import { getInstructionDescriptor } from '@subsquid/solana-stream'
import * as attestation from '../../abi/solana_attestation_service'
import { Buffer } from 'buffer'

// Base record interface
export interface BaseRecord {
  slot: number;
  timestamp: Date;
  instructionType: string;
  transactionHash: string;
}

// Credential-related records
export interface CredentialRecord extends BaseRecord {
  credentialPda: string;
  authority: string;
  name: string;
  signers: string[];
  previousSigners?: string[];
}

// Schema-related records
export interface SchemaRecord extends BaseRecord {
  schemaPda: string;
  credentialPda: string;
  authority: string;
  name: string;
  description: string;
  previousDescription?: string;
  layoutBuffer: string;
  fieldNames: string[];
  isPaused?: boolean;
  previousStatus?: boolean;
  existingSchemaPda?: string;
  newSchemaPda?: string;
}

// Attestation-related records
export interface AttestationRecord extends BaseRecord {
  attestationPda: string;
  credentialPda: string;
  schemaPda: string;
  authority: string;
  nonce?: string;
  claimData: string;
  expiry?: number;
  isTokenized: boolean;
  tokenName?: string;
  tokenUri?: string;
  tokenSymbol?: string;
  mintAccountSpace?: number;
  attestationMint?: string;
  schemaMint?: string;
  recipient?: string;
  recipientTokenAccount?: string;
}

// Tokenization records
export interface TokenizationRecord extends BaseRecord {
  schemaPda: string;
  credentialPda: string;
  authority: string;
  mintPda: string;
  maxSize: number;
  sasPda: string;
}

// Event records
export interface EventRecord extends BaseRecord {
  eventAuthority: string;
  eventData?: string;
}

// Union type for all records
export type SASRecord = CredentialRecord | SchemaRecord | AttestationRecord | TokenizationRecord | EventRecord;


export class AttestationsStream extends PortalAbstractStream<SASRecord> {
  async stream(): Promise<ReadableStream<SASRecord[]>> {
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
          d1: [
            attestation.instructions.createCredential.d1,
            attestation.instructions.createSchema.d1,
            attestation.instructions.changeSchemaStatus.d1,
            attestation.instructions.changeAuthorizedSigners.d1,
            attestation.instructions.changeSchemaDescription.d1,
            attestation.instructions.changeSchemaVersion.d1,
            attestation.instructions.createAttestation.d1,
            attestation.instructions.closeAttestation.d1,
            attestation.instructions.tokenizeSchema.d1,
            attestation.instructions.createTokenizedAttestation.d1,
            attestation.instructions.closeTokenizedAttestation.d1,
            attestation.instructions.emitEvent.d1,
          ],
          isCommitted: true,
          transaction: true,
        },
      ],
    })

    return source.pipeThrough(
      new TransformStream({
        transform: ({ blocks }, controller) => {
          const records: SASRecord[] = []

          blocks.forEach((block: any) => {
            if (!block.instructions) return

            for (const ins of block.instructions) {
              const descriptor = getInstructionDescriptor(ins)
              const firstByte = descriptor.slice(0, 4) // Get first byte as "0x06" format
              
              if (ins.programId !== attestation.programId) {
                continue
              }

              const baseRecord = {
                slot: block.header.number,
                timestamp: new Date(block.header.timestamp * 1000),
                instructionType: this.getInstructionTypeName(firstByte),
                transactionHash: block.transactions?.[ins.transactionIndex]?.signatures?.[0] || '',
              }

              try {
                const record = this.parseInstruction(firstByte, ins, baseRecord)
                if (record) {
                  records.push(record)
                }
              } catch (error) {
                console.error(`Failed to parse instruction ${firstByte}:`, error)
              }
            }
          })

          controller.enqueue(records)
        },
      }),
    )
  }

  private getInstructionTypeName(discriminator: string): string {
    const mapping: Record<string, string> = {
      [attestation.instructions.createCredential.d1]: 'createCredential',
      [attestation.instructions.createSchema.d1]: 'createSchema',
      [attestation.instructions.changeSchemaStatus.d1]: 'changeSchemaStatus',
      [attestation.instructions.changeAuthorizedSigners.d1]: 'changeAuthorizedSigners',
      [attestation.instructions.changeSchemaDescription.d1]: 'changeSchemaDescription',
      [attestation.instructions.changeSchemaVersion.d1]: 'changeSchemaVersion',
      [attestation.instructions.createAttestation.d1]: 'createAttestation',
      [attestation.instructions.closeAttestation.d1]: 'closeAttestation',
      [attestation.instructions.tokenizeSchema.d1]: 'tokenizeSchema',
      [attestation.instructions.createTokenizedAttestation.d1]: 'createTokenizedAttestation',
      [attestation.instructions.closeTokenizedAttestation.d1]: 'closeTokenizedAttestation',
      [attestation.instructions.emitEvent.d1]: 'emitEvent',
    }
    return mapping[discriminator] || 'unknown'
  }

  private parseInstruction(discriminator: string, ins: any, baseRecord: any): SASRecord | null {
    switch (discriminator) {
      case attestation.instructions.createCredential.d1:
        return this.parseCreateCredential(ins, baseRecord)
      
      case attestation.instructions.createSchema.d1:
        return this.parseCreateSchema(ins, baseRecord)
      
      case attestation.instructions.changeSchemaStatus.d1:
        return this.parseChangeSchemaStatus(ins, baseRecord)
      
      case attestation.instructions.changeAuthorizedSigners.d1:
        return this.parseChangeAuthorizedSigners(ins, baseRecord)
      
      case attestation.instructions.changeSchemaDescription.d1:
        return this.parseChangeSchemaDescription(ins, baseRecord)
      
      case attestation.instructions.changeSchemaVersion.d1:
        return this.parseChangeSchemaVersion(ins, baseRecord)
      
      case attestation.instructions.createAttestation.d1:
        return this.parseCreateAttestation(ins, baseRecord)
      
      case attestation.instructions.closeAttestation.d1:
        return this.parseCloseAttestation(ins, baseRecord)
      
      case attestation.instructions.tokenizeSchema.d1:
        return this.parseTokenizeSchema(ins, baseRecord)
      
      case attestation.instructions.createTokenizedAttestation.d1:
        return this.parseCreateTokenizedAttestation(ins, baseRecord)
      
      case attestation.instructions.closeTokenizedAttestation.d1:
        return this.parseCloseTokenizedAttestation(ins, baseRecord)
      
      case attestation.instructions.emitEvent.d1:
        return this.parseEmitEvent(ins, baseRecord)
      
      default:
        return null
    }
  }

  private parseCreateCredential(ins: any, baseRecord: any): CredentialRecord {
    const decoded = attestation.instructions.createCredential.decode(ins)
    return {
      ...baseRecord,
      credentialPda: decoded.accounts.credential,
      authority: decoded.accounts.authority,
      name: decoded.data.name,
      signers: decoded.data.signers,
    }
  }

  private parseCreateSchema(ins: any, baseRecord: any): SchemaRecord {
    const decoded = attestation.instructions.createSchema.decode(ins)
    return {
      ...baseRecord,
      schemaPda: decoded.accounts.schema,
      credentialPda: decoded.accounts.credential,
      authority: decoded.accounts.authority,
      name: decoded.data.name,
      description: decoded.data.description,
      layoutBuffer: Buffer.from(decoded.data.layout).toString('hex'),
      fieldNames: decoded.data.fieldNames,
    }
  }

  private parseChangeSchemaStatus(ins: any, baseRecord: any): SchemaRecord {
    const decoded = attestation.instructions.changeSchemaStatus.decode(ins)
    return {
      ...baseRecord,
      schemaPda: decoded.accounts.schema,
      credentialPda: decoded.accounts.credential,
      authority: decoded.accounts.authority,
      name: '', // Will need to be filled from existing schema data
      description: '', // Will need to be filled from existing schema data
      layoutBuffer: '',
      fieldNames: [],
      isPaused: decoded.data.isPaused,
    }
  }

  private parseChangeAuthorizedSigners(ins: any, baseRecord: any): CredentialRecord {
    const decoded = attestation.instructions.changeAuthorizedSigners.decode(ins)
    return {
      ...baseRecord,
      credentialPda: decoded.accounts.credential,
      authority: decoded.accounts.authority,
      name: '', // Will need to be filled from existing credential data
      signers: decoded.data.signers,
    }
  }

  private parseChangeSchemaDescription(ins: any, baseRecord: any): SchemaRecord {
    const decoded = attestation.instructions.changeSchemaDescription.decode(ins)
    return {
      ...baseRecord,
      schemaPda: decoded.accounts.schema,
      credentialPda: decoded.accounts.credential,
      authority: decoded.accounts.authority,
      name: '', // Will need to be filled from existing schema data
      description: decoded.data.description,
      layoutBuffer: '',
      fieldNames: [],
    }
  }

  private parseChangeSchemaVersion(ins: any, baseRecord: any): SchemaRecord {
    const decoded = attestation.instructions.changeSchemaVersion.decode(ins)
    return {
      ...baseRecord,
      schemaPda: decoded.accounts.newSchema,
      credentialPda: decoded.accounts.credential,
      authority: decoded.accounts.authority,
      name: '', // Will need to be filled from existing schema data
      description: '',
      layoutBuffer: Buffer.from(decoded.data.layout).toString('hex'),
      fieldNames: decoded.data.fieldNames,
      existingSchemaPda: decoded.accounts.existingSchema,
      newSchemaPda: decoded.accounts.newSchema,
    }
  }

  private parseCreateAttestation(ins: any, baseRecord: any): AttestationRecord {
    const decoded = attestation.instructions.createAttestation.decode(ins)
    
    // Try to decode as JSON first, fallback to hex if it fails
    let claimData: string
    try {
      const dataString = Buffer.from(decoded.data.data).toString('utf8')
      // Try to parse as JSON to validate it's valid JSON
      JSON.parse(dataString)
      claimData = dataString
    } catch (e) {
      // If JSON parsing fails, store as hex
      claimData = Buffer.from(decoded.data.data).toString('hex')
    }

    return {
      ...baseRecord,
      attestationPda: decoded.accounts.attestation,
      credentialPda: decoded.accounts.credential,
      schemaPda: decoded.accounts.schema,
      authority: decoded.accounts.authority,
      nonce: decoded.data.nonce,
      claimData: claimData,
      expiry: Number(decoded.data.expiry),
      isTokenized: false,
    }
  }

  private parseCloseAttestation(ins: any, baseRecord: any): AttestationRecord {
    const decoded = attestation.instructions.closeAttestation.decode(ins)
    return {
      ...baseRecord,
      attestationPda: decoded.accounts.attestation,
      credentialPda: decoded.accounts.credential,
      schemaPda: '', // Will need to be filled from existing attestation data
      authority: decoded.accounts.authority,
      claimData: '',
      isTokenized: false,
    }
  }

  private parseTokenizeSchema(ins: any, baseRecord: any): TokenizationRecord {
    const decoded = attestation.instructions.tokenizeSchema.decode(ins)
    return {
      ...baseRecord,
      schemaPda: decoded.accounts.schema,
      credentialPda: decoded.accounts.credential,
      authority: decoded.accounts.authority,
      mintPda: decoded.accounts.mint,
      maxSize: Number(decoded.data.maxSize),
      sasPda: decoded.accounts.sasPda,
    }
  }

  private parseCreateTokenizedAttestation(ins: any, baseRecord: any): AttestationRecord {
    const decoded = attestation.instructions.createTokenizedAttestation.decode(ins)
    
    // Try to decode as JSON first, fallback to hex if it fails
    let claimData: string
    try {
      const dataString = Buffer.from(decoded.data.data).toString('utf8')
      // Try to parse as JSON to validate it's valid JSON
      JSON.parse(dataString)
      claimData = dataString
    } catch (e) {
      // If JSON parsing fails, store as hex
      claimData = Buffer.from(decoded.data.data).toString('hex')
    }

    return {
      ...baseRecord,
      attestationPda: decoded.accounts.attestation,
      credentialPda: decoded.accounts.credential,
      schemaPda: decoded.accounts.schema,
      authority: decoded.accounts.authority,
      nonce: decoded.data.nonce,
      claimData: claimData,
      expiry: Number(decoded.data.expiry),
      isTokenized: true,
      tokenName: decoded.data.name,
      tokenUri: decoded.data.uri,
      tokenSymbol: decoded.data.symbol,
      mintAccountSpace: decoded.data.mintAccountSpace,
      attestationMint: decoded.accounts.attestationMint,
      schemaMint: decoded.accounts.schemaMint,
      recipient: decoded.accounts.recipient,
      recipientTokenAccount: decoded.accounts.recipientTokenAccount,
    }
  }

  private parseCloseTokenizedAttestation(ins: any, baseRecord: any): AttestationRecord {
    const decoded = attestation.instructions.closeTokenizedAttestation.decode(ins)
    return {
      ...baseRecord,
      attestationPda: decoded.accounts.attestation,
      credentialPda: decoded.accounts.credential,
      schemaPda: '', // Will need to be filled from existing attestation data
      authority: decoded.accounts.authority,
      claimData: '',
      isTokenized: true,
      attestationMint: decoded.accounts.attestationMint,
    }
  }

  private parseEmitEvent(ins: any, baseRecord: any): EventRecord {
    const decoded = attestation.instructions.emitEvent.decode(ins)
    return {
      ...baseRecord,
      eventAuthority: decoded.accounts.eventAuthority,
      eventData: '',
    }
  }
}

