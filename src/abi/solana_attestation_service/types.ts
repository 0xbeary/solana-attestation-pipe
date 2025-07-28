import {Codec, struct, u8, address, binary, i64, array, bool} from '@subsquid/borsh'

export interface CloseAttestationEvent {
    discriminator: number
    schema: string
    attestationData: Uint8Array
}

export const CloseAttestationEvent: Codec<CloseAttestationEvent> = struct({
    discriminator: u8,
    schema: address,
    attestationData: binary,
})

export interface Attestation {
    nonce: string
    credential: string
    schema: string
    data: Uint8Array
    signer: string
    expiry: bigint
    tokenAccount: string
}

export const Attestation: Codec<Attestation> = struct({
    nonce: address,
    credential: address,
    schema: address,
    data: binary,
    signer: address,
    expiry: i64,
    tokenAccount: address,
})

export interface Credential {
    authority: string
    name: Uint8Array
    authorizedSigners: Array<string>
}

export const Credential: Codec<Credential> = struct({
    authority: address,
    name: binary,
    authorizedSigners: array(address),
})

export interface Schema {
    credential: string
    name: Uint8Array
    description: Uint8Array
    layout: Uint8Array
    fieldNames: Uint8Array
    isPaused: boolean
    version: number
}

export const Schema: Codec<Schema> = struct({
    credential: address,
    name: binary,
    description: binary,
    layout: binary,
    fieldNames: binary,
    isPaused: bool,
    version: u8,
})
