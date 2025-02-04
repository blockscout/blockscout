# Confirmation Processing Modules

This directory contains modules that handle the discovery and processing of rollup block confirmations in the Arbitrum indexer.

## Module Overview

- **`discovery.ex`**  
  Contains the core logic to identify, adjust, and process rollup block ranges. It dynamically handles reorg scenarios and determines which rollup blocks should be re-evaluated for confirmation updates.

- **`events.ex`**  
  Provides utilities for fetching, filtering, and parsing `SendRootUpdated` events from the Arbitrum outbox. These events serve as triggers for initiating the confirmation process.

- **`rollup_blocks.ex`**  
  Updates the status of rollup blocks by mapping confirmed rollup data to the corresponding parent chain transactions, ensuring a precise association between rollup blocks and the confirmation events that first marked them.

- **`tasks.ex`**  
  Acts as the orchestrator for both new and historical confirmation discovery workflows, triggering the processing flow across the other modules.

## Architecture

The confirmation processing leverages a multi-layered design linking different responsibilities:

1. **Call Flow:**  
   - **Tasks Module:** Serves as the entry point, triggering and scheduling confirmation discovery.
   - **Discovery Module:** Adjusts block ranges, detects reorg events, and prepares the set of rollup
     blocks for confirmation.
   - **Rollup Blocks Module:** Correlates and updates confirmation statuses by linking rollup block data
     to parent chain transactions.

2. **Arbitrum Settlement Mechanism:**  
   - **Rollup Entities:** Represent the on-chain Arbitrum block data that require confirmation.
   - **Parent Chain Batches:** Organize groups of related transactions or state changes processed
     on the parent chain.
   - **Confirmations:** Finalize the state by matching parent chain confirmations with the updated rollup
     entities.
   - **L2-to-L1 Messages:** As part of the confirmation process, messages that were included in
     transactions within confirmed rollup blocks are also marked as confirmed. This ensures that the cross-chain message status accurately reflects the settlement state.

   - **Confirmation Order Handling:**  
     The logic respects the order of confirmation events:
     - A confirmation on the Arbitrum chain marks all rollup blocks below a given block as confirmed.
     - However, the indexer refines this by recording which concrete confirmation confirmed each rollup block first. For example:
       - Confirmation **A** in parent chain block **O** confirms rollup block **X** and all blocks below.
       - Confirmation **B** in parent chain block **P** (with P < O) confirms rollup block **Y** and all blocks below.
       - Confirmation **C** in parent chain block **Q** (with Q < P) confirms rollup block **Z** and all blocks below.
     - Although Arbitrum's logic implies that all blocks X and below are confirmed by **A**, the indexer builds the following linkage:
       - Rollup blocks from **X** down to just above **Y** are confirmed by **A**.
       - Rollup blocks from **Y** down to just above **Z** are confirmed by **B**.
     - This nuanced mapping preserves confirmation order and allows accurate tracking of when a rollup block was first confirmed.

## Update & Extension Guidelines

When modifying or extending the confirmation processing functionality, consider the following
architectural aspects:

### Call Flow Integrity
- **Maintain the Task → Discovery → Rollup Blocks Chain:**  
  Ensure any changes preserve the separation of responsibilities:
  - **Tasks** should remain the central trigger.
  - **Discovery** must continue to adjust block ranges and handle reorg-related issues.
  - **Rollup Blocks** is responsible for linking rollup data with the appropriate confirmations.
- **Data Consistency:**  
  Any new functionality must produce data in the format expected by downstream modules.

### Handling of Edge Cases
- **Managing Reorgs:**  
  Enhance detection and recovery mechanisms so that reorgs on the parent chain are handled gracefully.
  - Support operating with "safe blocks" that represent a confirmed and stable state of the blockchain.
  - Enable querying of logs from the parent chain with overlapping block ranges while skipping already discovered confirmations to avoid redundant processing.
- **Incomplete Data:**  
  At the moment of confirmation discovery, the indexer might be in a state where corresponding
  rollup blocks or parent chain batches have not yet been fetched. Implement lazy fetching and robust error handling to accommodate these asynchronous data flows.
- **Selective Discovery:**  
  The indexer configuration might limit fetched rollup blocks (e.g., not starting from genesis). Thus, the confirmation discovery process should operate only within the available and relevant block range rather than enforcing discovery across all historical data.

## Module Organization

The confirmation functionality is split across multiple modules rather than maintained in a single monolithic file for two primary reasons:

### 1. Collaborative Development

Splitting functionality across multiple files significantly reduces the likelihood of merge conflicts when multiple developers are working on different features simultaneously. Each module can be modified independently without affecting other parts of the codebase.

### 2. LLM-Based Development Optimization

The modular structure is specifically designed to work better with Large Language Model (LLM) based coding assistants:

- **Output Token Efficiency**: While modern LLMs can handle large files in their input context, they still have limitations on output tokens. Smaller files make it easier for AI assistants to propose and explain changes within these limits.

- **Focus Window Management**: Smaller, focused modules help maintain a clear context window when working with AI assistants, making it easier to discuss and modify specific functionality without the noise of unrelated code.