# Batch Processing Modules

This directory contains modules that handle the discovery and processing of Arbitrum rollup batches, managing the core batch-related operations in the Blockscout indexer.

## Module Overview

- `discovery.ex` - Discovers and processes batches from multiple data sources
- `discovery_utils.ex` - Helper functions for batch discovery and processing
- `events.ex` - Handles event log retrieval and processing
- `rollup_entities.ex` - Manages rollup block and transaction associations
- `tasks.ex` - Orchestrates batch discovery workflows

## Batch Data Sources

The indexer supports multiple data storage mechanisms for batch data:
- Transaction calldata (traditional approach)
- Data Availability (DA) blobs (EIP-4844)
- AnyTrust solution
- Celestia DA layer

For each batch, the indexer:
1. Processes the `SequencerBatchDelivered` event
2. Extracts batch data from the corresponding source by analyzing the transaction that emitted the event
3. Builds comprehensive batch information including:
   - Batch boundaries
   - Included L2 transactions
   - Message data
   - Data availability information
4. Updates the status of L2-to-L1 messages included in the batch transactions to mark them as committed

## Entity Linkage

The batch processor creates and maintains relationships between:
- Batches and their corresponding rollup blocks
- Batches and included rollup transactions
- Parent chain transactions and batch data

This linkage is established even if the related entities (blocks or transactions) haven't been fetched yet by the main block fetcher, ensuring data consistency when the entities are eventually processed.

## Processing Patterns

Batch processing follows three main patterns:
- New batch discovery (forward processing)
- Historical batch discovery (backward processing)
- Missing batch detection (gap filling)

Data recovery mechanisms include:
- Automatic RPC fallback for missing data
- Chunk-based processing for large datasets
- Proper error handling and logging

## Handling of Edge Cases

The batch discovery process handles several important edge cases:

1. Legacy Batch Format
   - Some batches lack message counts in transaction calldata (from old SequencerInbox contract)
   - Block ranges are determined by analyzing neighboring batches
   - Binary search is used when only one neighbor is indexed

2. Data Recovery and Gaps
   - Automatically recovers missing rollup blocks and transactions via RPC
   - Identifies and processes missing batches in sequential numbering
   - Maps gaps to L1 block ranges for targeted recovery
   - Chunks large datasets to ensure partial progress on failures
   - Processes missing data in bounded ranges for efficiency

3. Chain Reorganization
   - Uses safe block numbers to prevent reorg issues
   - Re-processes commitment transactions for existing batches
   - Updates block numbers and timestamps if reorg detected
   - Maintains consistency between L1 and L2 data
   - Adjusts ranges when safe blocks affect discovery windows

4. Batch Zero Handling
   - Explicitly skips batch number 0 as it contains no rollup blocks/transactions
   - Adjusts block counting for first valid batch accordingly

5. Initial Block Detection
   - The indexer configuration might limit fetched rollup blocks (e.g., not starting from genesis). Thus, the batch discovery process should operate only within the available and relevant block range rather than enforcing discovery across all historical data.

## Module Organization

The batch processing functionality is split across multiple modules rather than maintained in a single monolithic file for two primary reasons:

### 1. Collaborative Development

Splitting functionality across multiple files significantly reduces the likelihood of merge conflicts when multiple developers are working on different features simultaneously. Each module can be modified independently without affecting other parts of the codebase.

### 2. LLM-Based Development Optimization

The modular structure is specifically designed to work better with Large Language Model (LLM) based coding assistants:

- **Output Token Efficiency**: While modern LLMs can handle large files in their input context, they still have limitations on output tokens. Smaller files make it easier for AI assistants to propose and explain changes within these limits.

- **Focus Window Management**: Smaller, focused modules help maintain a clear context window when working with AI assistants, making it easier to discuss and modify specific functionality without the noise of unrelated code.