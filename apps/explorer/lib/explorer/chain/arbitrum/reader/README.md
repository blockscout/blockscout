# Arbitrum Reader Modules

This directory contains modules that provide structured access to Arbitrum-specific data stored in the Blockscout database.

## Module Overview

- `api/` - API endpoint-specific functions:
  - `messages.ex` - Cross-chain message queries
  - `settlement.ex` - Batch management, DA blob data, and rollup blocks
  - `general.ex` - General utility functions like transaction log queries
- `common.ex` - Core query functionality shared between different components (API, Indexer) with configurable database selection
- `indexer/messages.ex` - Cross-chain message handling
- `indexer/parent_chain_transactions.ex` - L1 transaction lifecycle
- `indexer/settlement.ex` - Batch and state confirmation data
- `indexer/general.ex` - Chain-agnostic functions

## Important Usage Note

Functions in the `indexer/` modules should not be called directly. Instead, use the corresponding wrapper functions provided in the `Explorer.Chain.Indexer.Fetcher.Arbitrum.Utils.Db` module. The wrapper functions provide:

- Additional data transformation specific to indexer needs
- Enhanced error handling

This separation ensures that database operations are properly handled and maintains a clear boundary between raw database access and indexer-specific business logic.

## Module Organization

The reader functionality is split across multiple modules rather than maintained in a single monolithic file for two primary reasons:

### 1. Collaborative Development

Splitting functionality across multiple files significantly reduces the likelihood of merge conflicts when multiple developers are working on different features simultaneously. Each module can be modified independently without affecting other parts of the codebase.

### 2. LLM-Based Development Optimization

The modular structure is specifically designed to work better with Large Language Model (LLM) based coding assistants:

- **Output Token Efficiency**: While modern LLMs can handle large files in their input context, they still have limitations on output tokens. Smaller files make it easier for AI assistants to propose and explain changes within these limits.

- **Focus Window Management**: Smaller, focused modules help maintain a clear context window when working with AI assistants, making it easier to discuss and modify specific functionality without the noise of unrelated code.