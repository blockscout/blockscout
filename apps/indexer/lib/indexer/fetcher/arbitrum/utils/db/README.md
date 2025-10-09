# Database Utility Modules

This directory contains modules that provide structured database access and manipulation for Arbitrum-specific data in the Blockscout indexer.

## Module Overview

- `common.ex` - Chain-agnostic database utility functions for block-related operations
- `messages.ex` - Functions for querying and managing cross-chain message data
- `parent_chain_transactions.ex` - Handles L1 transaction indexing and lifecycle management
- `settlement.ex` - Manages batch commitment and state confirmation data
- `tools.ex` - Internal helper functions for database record processing

## Usage Guidelines

1. Use logging judiciously to avoid overwhelming the logs with unnecessary information

2. Use Reader modules from `Explorer.Chain.Arbitrum.Reader` namespace for raw database access if other modules under `Explorer.Chain` do not provide the functionality you need.

3. Apply additional data transformation to maintain consistency with structures used for data import

4. Implement proper error handling when database queries return `nil`

## Module Organization 

The database functionality is split across multiple modules rather than maintained in a single monolithic file for two primary reasons:

### 1. Collaborative Development

Splitting functionality across multiple files significantly reduces the likelihood of merge conflicts when multiple developers are working on different features simultaneously. Each module can be modified independently without affecting other parts of the codebase.

### 2. LLM-Based Development Optimization

The modular structure is specifically designed to work better with Large Language Model (LLM) based coding assistants:

- **Output Token Efficiency**: While modern LLMs can handle large files in their input context, they still have limitations on output tokens. Smaller files make it easier for AI assistants to propose and explain changes within these limits.

- **Focus Window Management**: Smaller, focused modules help maintain a clear context window when working with AI assistants, making it easier to discuss and modify specific functionality without the noise of unrelated code.
