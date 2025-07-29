import { createClient } from '@clickhouse/client'
import { readFileSync } from 'fs'
import { join } from 'path'

export function getQueryExplanation(description: string): string {
  const explanations: Record<string, string> = {
    'Table Status Check': 
      'Health check to verify all tables exist and have data, showing latest slots and record counts.',
    
    'Overall Data Summary': 
      'Basic overview of total instructions and time range across all SAS instruction types.',
    
    'Instruction Type Distribution': 
      'Breakdown of all instruction types and their frequency to understand ecosystem usage patterns.',
    
    'Top Credential Authorities': 
      'Authorities with the most credential creation activity, showing their ecosystem influence.',
    
    'Most Complex Schemas': 
      'Schemas ranked by field count and layout size to identify the most sophisticated credential structures.',
    
    'Recent Attestation Activity (Last 30 Days)': 
      'Daily attestation activity breakdown for the past month showing recent ecosystem trends.',
    
    'Schema Performance Analysis': 
      'Analyzes attestation volume and tokenization rates by schema, revealing which credential types are most successful and adopted.',
    
    'Tokenized Attestation Analysis': 
      'Deep dive into tokenized attestation patterns, showing token metadata usage and recipient distribution.',
    
    'Authority Influence Ranking': 
      'Calculates authority influence scores based on credential control, schema management, and attestation volume.',
    
    'Schema Complexity vs Usage Analysis': 
      'Correlates schema field complexity with actual usage patterns to identify optimal schema designs.',
    
    'Daily Ecosystem Activity Timeline': 
      'Tracks daily activity across all SAS instruction types to identify growth trends and usage patterns.',
    
    'Attestation Closure Patterns': 
      'Analyzes attestation closure behavior, comparing regular vs tokenized closure rates.',
    
    'Cross-Program Tokenization Impact': 
      'Measures the effectiveness of schema tokenization by tracking subsequent tokenized attestation creation.',
    
    'Sample Attestation Data Inspection': 
      'Detailed look at individual attestation data formats and content to understand data structures.',
    
    'Attestation Content Analysis by Schema': 
      'Analysis of claim data formats and sizes by schema to understand content patterns.',
    
    'Identity Verification Attestations': 
      'Focus on schemas with identity-related fields to analyze identity verification use cases.',
    
    'Professional Attestations Analysis': 
      'Focus on work/employment-related attestations to understand professional credential patterns.',
    
    'Attestation Data Size and Complexity': 
      'Categorize attestations by data size and analyze patterns to understand complexity distributions.',
    
    'Expiry Patterns and Use Cases': 
      'Analysis of attestation expiration patterns to understand temporal usage characteristics.',
    
    'Common Claim Data Patterns': 
      'Analysis of JSON-formatted claim data patterns to understand common data structures.',
    
    'Tokenized Attestation Recipients and Use Cases': 
      'Analysis of tokenized attestation distribution and usage to understand SPL Token integration patterns.'
  }
  
  return explanations[description] || 'Analysis query for SAS ecosystem insights.'
}

export function loadSqlQuery(filename: string, folder: string = ''): string {
  let queryPath: string | undefined
  
  if (folder) {
    queryPath = join(process.cwd(), 'queries', folder, filename)
  } else {
    // For backward compatibility, try to find the file in any subfolder
    const fs = require('fs')
    const path = require('path')
    const queriesDir = join(process.cwd(), 'queries')
    
    // Search through all subdirectories
    const searchDirs = ['basic', 'analytics', 'attestations', 'tokenization']
    
    for (const dir of searchDirs) {
      const testPath = join(queriesDir, dir, filename)
      if (fs.existsSync(testPath)) {
        queryPath = testPath
        break
      }
    }
    
    if (!queryPath) {
      throw new Error(`Query file ${filename} not found in any queries subfolder`)
    }
  }
  
  return readFileSync(queryPath, 'utf8')
}

export async function executeQuery(query: string, description: string, limitResults: boolean = true) {
  const client = createClient({
    url: 'http://localhost:8123',
    database: 'default',
  })

  try {
    console.log(`\n=== ${description} ===`)
    console.log(`${getQueryExplanation(description)}`)
    
    const result = await client.query({
      query,
      format: 'JSONEachRow',
    })
    
    const data = await result.json()
    console.log('Results:')
    
    if (limitResults && data.length > 10) {
      console.table(data.slice(0, 10))
      console.log(`... and ${data.length - 10} more rows`)
    } else {
      console.table(data)
    }
    
    return data
  } catch (error) {
    console.error(`Error executing query: ${error}`)
    return null
  } finally {
    await client.close()
  }
}
