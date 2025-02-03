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

## Module Organization

The batch processing functionality is split across multiple modules rather than maintained in a single monolithic file for two primary reasons:

### 1. Collaborative Development

Splitting functionality across multiple files significantly reduces the likelihood of merge conflicts when multiple developers are working on different features simultaneously. Each module can be modified independently without affecting other parts of the codebase.

### 2. LLM-Based Development Optimization

The modular structure is specifically designed to work better with Large Language Model (LLM) based coding assistants:

- **Output Token Efficiency**: While modern LLMs can handle large files in their input context, they still have limitations on output tokens. Smaller files make it easier for AI assistants to propose and explain changes within these limits.

- **Focus Window Management**: Smaller, focused modules help maintain a clear context window when working with AI assistants, making it easier to discuss and modify specific functionality without the noise of unrelated code.