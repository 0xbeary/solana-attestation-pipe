import {struct, string, array, address, binary, bool, i64, unit, u64, u16} from '@subsquid/borsh'
import {instruction} from '../abi.support'

export interface CreateCredential {
    name: string
    signers: Array<string>
}

export const createCredential = instruction(
    {
        d1: '0x00',
    },
    {
        payer: 0,
        credential: 1,
        authority: 2,
        systemProgram: 3,
    },
    struct({
        name: string,
        signers: array(address),
    }),
)

export interface CreateSchema {
    name: string
    description: string
    layout: Uint8Array
    fieldNames: Array<string>
}

export const createSchema = instruction(
    {
        d1: '0x01',
    },
    {
        payer: 0,
        authority: 1,
        /**
         * Credential the Schema is associated with
         */
        credential: 2,
        schema: 3,
        systemProgram: 4,
    },
    struct({
        name: string,
        description: string,
        layout: binary,
        fieldNames: array(string),
    }),
)

export interface ChangeSchemaStatus {
    isPaused: boolean
}

export const changeSchemaStatus = instruction(
    {
        d1: '0x02',
    },
    {
        authority: 0,
        /**
         * Credential the Schema is associated with
         */
        credential: 1,
        /**
         * Credential the Schema is associated with
         */
        schema: 2,
    },
    struct({
        isPaused: bool,
    }),
)

export interface ChangeAuthorizedSigners {
    signers: Array<string>
}

export const changeAuthorizedSigners = instruction(
    {
        d1: '0x03',
    },
    {
        payer: 0,
        authority: 1,
        /**
         * Credential the Schema is associated with
         */
        credential: 2,
        systemProgram: 3,
    },
    struct({
        signers: array(address),
    }),
)

export interface ChangeSchemaDescription {
    description: string
}

export const changeSchemaDescription = instruction(
    {
        d1: '0x04',
    },
    {
        payer: 0,
        authority: 1,
        /**
         * Credential the Schema is associated with
         */
        credential: 2,
        /**
         * Credential the Schema is associated with
         */
        schema: 3,
        systemProgram: 4,
    },
    struct({
        description: string,
    }),
)

export interface ChangeSchemaVersion {
    layout: Uint8Array
    fieldNames: Array<string>
}

export const changeSchemaVersion = instruction(
    {
        d1: '0x05',
    },
    {
        payer: 0,
        authority: 1,
        /**
         * Credential the Schema is associated with
         */
        credential: 2,
        existingSchema: 3,
        newSchema: 4,
        systemProgram: 5,
    },
    struct({
        layout: binary,
        fieldNames: array(string),
    }),
)

export interface CreateAttestation {
    nonce: string
    data: Uint8Array
    expiry: bigint
}

export const createAttestation = instruction(
    {
        d1: '0x06',
    },
    {
        payer: 0,
        /**
         * Authorized signer of the Schema's Credential
         */
        authority: 1,
        /**
         * Credential the Schema is associated with
         */
        credential: 2,
        /**
         * Schema the Attestation is associated with
         */
        schema: 3,
        attestation: 4,
        systemProgram: 5,
    },
    struct({
        nonce: address,
        data: binary,
        expiry: i64,
    }),
)

export type CloseAttestation = undefined

export const closeAttestation = instruction(
    {
        d1: '0x07',
    },
    {
        payer: 0,
        /**
         * Authorized signer of the Schema's Credential
         */
        authority: 1,
        credential: 2,
        attestation: 3,
        eventAuthority: 4,
        systemProgram: 5,
        attestationProgram: 6,
    },
    unit,
)

export interface TokenizeSchema {
    maxSize: bigint
}

export const tokenizeSchema = instruction(
    {
        d1: '0x09',
    },
    {
        payer: 0,
        authority: 1,
        /**
         * Credential the Schema is associated with
         */
        credential: 2,
        schema: 3,
        /**
         * Mint of Schema Token
         */
        mint: 4,
        /**
         * Program derived address used as program signer authority
         */
        sasPda: 5,
        systemProgram: 6,
        tokenProgram: 7,
    },
    struct({
        maxSize: u64,
    }),
)

export interface CreateTokenizedAttestation {
    nonce: string
    data: Uint8Array
    expiry: bigint
    name: string
    uri: string
    symbol: string
    mintAccountSpace: number
}

export const createTokenizedAttestation = instruction(
    {
        d1: '0x0a',
    },
    {
        payer: 0,
        /**
         * Authorized signer of the Schema's Credential
         */
        authority: 1,
        /**
         * Credential the Schema is associated with
         */
        credential: 2,
        /**
         * Schema the Attestation is associated with
         */
        schema: 3,
        attestation: 4,
        systemProgram: 5,
        /**
         * Mint of Schema Token
         */
        schemaMint: 6,
        /**
         * Mint of Attestation Token
         */
        attestationMint: 7,
        /**
         * Program derived address used as program signer authority
         */
        sasPda: 8,
        /**
         * Associated token account of Recipient for Attestation Token
         */
        recipientTokenAccount: 9,
        /**
         * Wallet to receive Attestation Token
         */
        recipient: 10,
        tokenProgram: 11,
        associatedTokenProgram: 12,
    },
    struct({
        nonce: address,
        data: binary,
        expiry: i64,
        name: string,
        uri: string,
        symbol: string,
        mintAccountSpace: u16,
    }),
)

export type CloseTokenizedAttestation = undefined

export const closeTokenizedAttestation = instruction(
    {
        d1: '0x0b',
    },
    {
        payer: 0,
        /**
         * Authorized signer of the Schema's Credential
         */
        authority: 1,
        credential: 2,
        attestation: 3,
        eventAuthority: 4,
        systemProgram: 5,
        attestationProgram: 6,
        /**
         * Mint of Attestation Token
         */
        attestationMint: 7,
        /**
         * Program derived address used as program signer authority
         */
        sasPda: 8,
        /**
         * Associated token account of the related Attestation Token
         */
        attestationTokenAccount: 9,
        tokenProgram: 10,
    },
    unit,
)

export type EmitEvent = undefined

export const emitEvent = instruction(
    {
        d1: '0xe4',
    },
    {
        eventAuthority: 0,
    },
    unit,
)
