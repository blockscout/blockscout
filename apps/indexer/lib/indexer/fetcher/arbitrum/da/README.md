# Data Availability Solution Extension Guide for Arbitrum/Orbit Rollups

This guide provides a comprehensive list of all files that need to be touched when extending the Blockscout indexer for Arbitrum-based (Orbit) rollups with support for new Data Availability (DA) solutions or updating existing DA solutions to newer versions.

## Overview

This document outlines the systematic approach required to add new DA solutions or update existing ones for Arbitrum-based rollups. The implementation typically follows a multi-phase approach to ensure stability and proper functionality.

## Prerequisites for New DA Solution Implementation

Before implementing support for a new DA solution, developers must research and understand the following requirements:

### 1. Contract Method ABI
**Requirement**: Complete ABI definition of the method used to commit Orbit batches to the base (L1) layer.

**Examples**:
- `addSequencerL2BatchFromEigenDA(uint256 sequenceNumber, EigenDACert calldata cert, ...)`
- `addSequencerL2BatchFromOrigin(uint256 sequenceNumber, bytes calldata data, ...)`

**Investigation needed**: Contract source code, deployment documentation, or ABI extraction from verified contracts.

### 2. DA Data Encoding Logic
**Requirement**: Understanding how DA-related data is encoded within the contract method parameters.

**Two patterns**:
- **Independent encoding**: DA data is part of generic `data` parameter (like in `addSequencerL2BatchFromOrigin`)
- **Explicit encoding**: DA data has dedicated parameter with specific structure (like `cert` in `addSequencerL2BatchFromEigenDA`)

**Investigation needed**: Contract implementation details, DA solution documentation, example transactions.

### 3. Data Storage Requirements
**Requirement**: Determine which DA information must be decoded/accessible vs. stored as binary blobs.

**Decoded information** (for API display):
- **Celestia**: Block height, transaction commitment
- **AnyTrust**: Data hash, timeout, signers mask, keyset information
- **EigenDA**: Blob metadata, certificate details

**Binary blob storage** (for completeness):
- **Celestia**: `raw` field containing complete blob descriptor
- **EigenDA**: Blob header and verification proof as encoded bytes

**Investigation needed**: What information do rollup operators and users need to see in the explorer UI?

### 4. Supplementary Data Collection
**Requirement**: Identify any additional information that must be collected separately from the batch committing transaction.

**Example**: AnyTrust keyset data
- **Primary DA record**: Certificate with keyset hash reference
- **Supplementary record**: Complete keyset details (threshold, committee member public keys)
- **Collection method**: Separate L1 event logs (`SetValidKeyset` events)

**Investigation needed**: Dependencies, cross-references, external data sources required for complete DA information.

### 5. Data Key Strategy
**Requirement**: Define how to uniquely identify DA records and link them with external explorers.

**Strategies**:
- **Celestia**: Hash of (block height + transaction commitment) - enables `/da/celestia/:height/:commitment` endpoints
- **AnyTrust**: Direct data hash usage - enables `/da/anytrust/:data_hash` endpoints  
- **EigenDA**: Hash of blob header - enables `/da/eigenda/:data_hash` endpoints

**Investigation needed**: What identifiers do external DA explorers use? How should backlinks be constructed?

### 6. Conflict Resolution Strategy
**Requirement**: Define how to handle duplicate DA records with the same identifier.

**Strategies**:
- **Simple deduplication**: Database record wins (Celestia/EigenDA pattern)
- **Value-based resolution**: Compare fields and keep better record (AnyTrust timeout comparison)
- **Custom logic**: DA-specific rules based on solution characteristics

**Investigation needed**: Are DA records immutable? Do they have quality metrics or validity periods?

## Preparation Checklist

Before starting implementation:
- [ ] Contract ABI obtained and validated
- [ ] DA encoding/decoding logic understood  
- [ ] Data storage requirements defined
- [ ] Supplementary data sources identified
- [ ] External explorer integration requirements clarified
- [ ] Conflict resolution strategy determined
- [ ] Test data and scenarios prepared

## Background: Understanding the Data Flow

To understand why specific files need modification, it's essential to understand how batch data flows through the Blockscout indexer and how Data Availability (DA) information is processed, stored, and served.

### Batch Discovery and Processing Flow

The core batch indexing process follows this flow:

```plaintext
Indexer.Fetcher.Arbitrum.Workers.Batches.Discovery.perform
  └─ Indexer.Fetcher.Arbitrum.Workers.Batches.Discovery.handle_batches_from_logs
      └─ Indexer.Fetcher.Arbitrum.Workers.Batches.Discovery.execute_transaction_requests_parse_transactions_calldata
          ├─ Indexer.Fetcher.Arbitrum.Utils.Rpc.parse_calldata_of_add_sequencer_l2_batch
          └─ Indexer.Fetcher.Arbitrum.DA.Common.examine_batch_accompanying_data
              └─ Indexer.Fetcher.Arbitrum.DA.Common.parse_data_availability_info
                  └─ Indexer.Fetcher.Arbitrum.DA.{Celestia,Anytrust,Eigenda}.parse_batch_accompanying_data
```

**Why this matters**: Each new DA solution requires updates at multiple points in this flow:

1. **RPC Layer**: `parse_calldata_of_add_sequencer_l2_batch` must recognize new method selectors and decode new transaction structures
2. **DA Common Layer**: `examine_batch_accompanying_data` must handle new DA type identifiers and route to appropriate parsers
3. **DA Specific Layer**: New DA modules must implement parsing logic for their specific data structures

### Data Import and Storage Flow

After parsing, DA information follows this import flow:

```plaintext
Indexer.Fetcher.Arbitrum.Workers.Batches.Discovery.execute_transaction_requests_parse_transactions_calldata
  └─ Indexer.Fetcher.Arbitrum.DA.Common.required_import?
  └─ Indexer.Fetcher.Arbitrum.DA.Common.prepare_for_import
      └─ Indexer.Fetcher.Arbitrum.DA.{Celestia,Anytrust,Eigenda}.prepare_for_import
          ├─ [AnyTrust] check_if_new_keyset → get_keyset_info_from_l1 (RPC calls)
          └─ [Others] Direct data preparation
      └─ Indexer.Fetcher.Arbitrum.DA.Common.eliminate_conflicts
          └─ Indexer.Fetcher.Arbitrum.DA.Common.process_records
              └─ Indexer.Fetcher.Arbitrum.DA.{Celestia,Anytrust,Eigenda}.resolve_conflict
```

**Why this matters**: Each DA solution has different parsing and storage requirements:

1. **Parsing Approaches**: 
   - **Celestia/AnyTrust**: Extract DA info during input parameter parsing
   - **EigenDA**: Full ABI decoding of complex nested structures

2. **Storage Requirements**: Not all DA information requires database storage
   - **Celestia/EigenDA**: Basic display information only
   - **AnyTrust**: Comprehensive data including committee member details and keysets

3. **Supplementary Data Collection**: Some DA solutions require additional data gathering during `prepare_for_import`
   - **AnyTrust**: Fetch keyset details via separate L1 RPC calls to retrieve `SetValidKeyset` events
   - **Complex operations**: May involve multiple RPC requests, event log parsing, or third-party data provider communication
   - **Performance impact**: Can significantly increase import processing time

4. **Data Import Logic**: Each DA solution creates specific database records that must be prepared and conflict-resolved

### API Rendering and Serving Flow

When serving batch information via API, the flow varies by DA solution complexity:

```plaintext
BlockScoutWeb.API.V2.ArbitrumController.batch
  └─ Explorer.Chain.Arbitrum.Reader.API.Settlement.batch
  └─ BlockScoutWeb.API.V2.ArbitrumView.render("arbitrum_batch.json", %{batch: batch})
      └─ BlockScoutWeb.API.V2.ArbitrumView.add_da_info
          ├─ generate_celestia_da_info (basic blob info)
          ├─ generate_anytrust_certificate (certificate + keyset lookup)
          │   └─ Explorer.Chain.Arbitrum.Reader.API.Settlement.get_da_info_by_batch_number
          │       └─ Fetch keyset details for committee information
          └─ generate_eigen_da_info (basic certificate info)
```

**Why this matters**: DA solutions have different rendering complexity:

1. **Basic Rendering** (Celestia/EigenDA): Simple metadata display
   - Height, commitment, blob headers
   - Direct mapping from database records

2. **Complex Rendering** (AnyTrust): Multi-record aggregation
   - Certificate data (data_type = 0) 
   - Keyset information (data_type = 1) for committee details
   - Cross-reference between records using keyset hash

3. **Schema Layer**: API response schemas must include new DA container types

### Reverse Lookup Flow (Data Hash to Batch)

DA solutions support different reverse lookup patterns based on their identifier schemes. These endpoints enable **backlink integration** with DA solution explorers (e.g., Celenium for Celestia, EigenDA Blob Explorer) to provide direct links to corresponding batch pages in Blockscout instances.

**Single-Parameter Lookups** (AnyTrust, EigenDA):
```plaintext
/api/v2/arbitrum/batches/da/{anytrust|eigenda}/:data_hash
  └─ BlockScoutWeb.API.V2.ArbitrumController.batch_by_data_availability_info
      └─ BlockScoutWeb.API.V2.ArbitrumController.one_batch_by_data_availability_info
          └─ Explorer.Chain.Arbitrum.Reader.API.Settlement.get_da_record_by_data_key
          └─ BlockScoutWeb.API.V2.ArbitrumController.batch
```

**Multi-Parameter Lookups** (Celestia):
```plaintext
/api/v2/arbitrum/batches/da/celestia/:height/:transaction_commitment
  └─ calculate_celestia_data_key(height, transaction_commitment)
  └─ [same lookup flow as above]
```

**Why this matters**: DA solutions have different identifier requirements and integration needs:

1. **Endpoint Design**: 
   - **AnyTrust/EigenDA**: Single hash parameter endpoints (`/batches/da/{solution}/:data_hash`)
   - **Celestia**: Multi-parameter endpoints (`/batches/da/celestia/:height/:transaction_commitment`)

2. **External Integration**: Enable DA solution explorers to provide backlinks
   - **Celenium (Celestia Explorer)**: Links from blob data to corresponding Arbitrum batch
   - **EigenDA Blob Explorer**: Links from blob certificates to rollup batch information
   - **AnyTrust explorers**: Links from data hash to batch details

3. **Data Key Calculation**: Helper functions must compute correct database keys
   - **AnyTrust**: Direct data hash usage
   - **Celestia**: Hash of (height + transaction_commitment)
   - **EigenDA**: Hash of blob header

4. **Database Indexing**: Efficient reverse lookups from computed keys to batch numbers

### Contract Integration Flow

The system must decode new contract method calls:

```plaintext
Smart Contract Method Call (addSequencerL2BatchFrom{DASolution})
  └─ EthereumJSONRPC.Arbitrum.Constants.Contracts.add_sequencer_l2_batch_from_{da_solution}_selector_with_abi
  └─ Indexer.Fetcher.Arbitrum.Utils.Rpc.parse_calldata_of_add_sequencer_l2_batch
      └─ ABI.TypeDecoder.decode(calldata, abi)
```

**Why this matters**: Each new DA solution typically introduces:

1. **New Contract Methods**: Different function signatures for batch submission
2. **Data Processing Variations**: Some DA solutions return decoded data as-is, others require preprocessing (e.g., EigenDA prepends a header byte flag)
3. **ABI Complexity**: Varies from simple parameters to complex nested structures requiring comprehensive ABI definitions

### Database Entity Relationships

DA information uses a flexible multi-purpose storage design:

```plaintext
arbitrum_l1_batches (batch_container field - indicates DA type)
  ├─ arbitrum_da_multi_purpose (main DA storage with type-based records)
  │   ├─ DA Records (data_type = 0): certificates, proofs, blob descriptors
  │   └─ Supplementary Records (data_type ≠ 0): keysets, additional metadata
  └─ arbitrum_batches_to_da_blobs (many-to-one batch-DA relationships)
      └─ Multiple batches can reference the same DA record when data is identical
```

**Why this matters**: The flexible design supports varying DA solution requirements:

1. **Multi-Purpose Storage**: `arbitrum_da_multi_purpose` stores JSON data with different `data_type` values
   - **Type 0**: Primary DA records (certificates, blob descriptors)
   - **Type 1+**: Supplementary records (e.g., AnyTrust keysets)

2. **Data Key Strategies**: Each DA solution uses different identifier schemes
   - **AnyTrust**: Data hash of the certificate
   - **Celestia**: Hash of (block height + transaction commitment)
   - **EigenDA**: Hash of blob header

3. **Storage Granularity**: Varies by DA solution based on display requirements
   - **Celestia/EigenDA**: Basic information (height, commitment, blob metadata)
   - **AnyTrust**: Comprehensive data (certificate + individual committee member contributions)

4. **Batch Relationships**: `arbitrum_batches_to_da_blobs` handles multiple batches referencing the same DA record (many-to-one relationship when batches contain identical data)

This interconnected architecture explains why implementing a new DA solution requires touching multiple layers of the system - from low-level contract parsing to high-level API responses. Each component serves a specific role in the overall data flow, and all must be updated cohesively to maintain system integrity.

## Complete File List

### 1. Core DA Module Files

**Location**: `apps/indexer/lib/indexer/fetcher/arbitrum/da/`

- `common.ex` - Core DA functionality that handles all DA types
- `{new_da_solution}.ex` - New DA-specific module (e.g., `eigenda.ex`, `celestia.ex`, `anytrust.ex`)

**Purpose**: 
- `common.ex` contains shared functionality for all DA solutions
- Individual DA modules handle parsing, preparation, and conflict resolution for specific DA types

### 2. Database Schema and Migrations

**Migration Files**: `apps/explorer/priv/arbitrum/migrations/`

- `{timestamp}_add_{da_solution}_batches.exs` - Adds new DA container type to enum
- (Reference: `20250731001757_add_eigenda_batches.exs` for EigenDA)
- (Reference: `20240527212653_add_da_info.exs` for original DA types)

**Schema Files**: `apps/explorer/lib/explorer/chain/arbitrum/`

- `l1_batch.ex` - Updates batch container enum and type definitions
- `da_multi_purpose_record.ex` - May need helper functions for data key calculation

**Purpose**: Define new DA container types and update database schema to support them.

### 3. RPC and Contract Interaction

**Files**:
- `apps/ethereum_jsonrpc/lib/ethereum_jsonrpc/arbitrum/constants/contracts.ex`
- `apps/indexer/lib/indexer/fetcher/arbitrum/utils/rpc.ex`

**Purpose**: 
- Add new method selectors and ABI definitions
- Update calldata parsing functions to handle new DA methods
- Define contract interaction patterns for new DA solutions

### 4. Batch Discovery and Processing

**Files**:
- `apps/indexer/lib/indexer/fetcher/arbitrum/workers/batches/discovery.ex`
- `apps/indexer/lib/indexer/fetcher/arbitrum/workers/batches/tasks.ex`
- `apps/indexer/lib/indexer/fetcher/arbitrum/workers/batches/README.md` (documentation)

**Purpose**: Handle batch discovery workflow and update documentation for new DA types.

### 5. API Layer

#### Controllers
**File**: `apps/block_scout_web/lib/block_scout_web/controllers/api/v2/arbitrum_controller.ex`

**Purpose**: Handle API endpoints for DA-specific batch lookups (e.g., `/batches/da/{da_solution}/:data_hash`) to enable integration with external DA explorers

#### Views
**File**: `apps/block_scout_web/lib/block_scout_web/views/api/v2/arbitrum_view.ex`

**Purpose**: 
- Add new DA info generation functions (e.g., `generate_{da_solution}_da_info`)
- Update `add_da_info` function to handle new DA container types
- Implement rendering logic for DA-specific information

#### Routing
**File**: `apps/block_scout_web/lib/block_scout_web/routers/api_router.ex`

**Purpose**: Add new API endpoints for DA-specific batch lookups, enabling backlink integration with DA solution explorers (Celenium, EigenDA Blob Explorer, etc.)

#### API Schemas
**File**: `apps/block_scout_web/lib/block_scout_web/schemas/api/v2/block.ex`

**Purpose**: Update API response schemas to include new DA container types in enums

### 6. Configuration and Documentation

**Files**:
- `cspell.json` - Add new DA solution terms to spell check dictionary
- `apps/indexer/lib/indexer/fetcher/arbitrum/workers/batches/README.md` - Update documentation

## Implementation Phases

### Phase 1: Basic Support (No Exception)
- Add method selector support in `contracts.ex`
- Update `parse_calldata_of_add_sequencer_l2_batch` in `rpc.ex`
- Return placeholder data to prevent indexing failures

### Phase 2: Database Schema Extension
- Create migration to add new DA container type to enum
- Update `l1_batch.ex` schema definitions:
  - Add new enum value to `batch_container` field definition
  - Update type specifications to include new DA container type
- Update type specifications in `common.ex`:
  - Add new DA type to `@spec` definitions that enumerate DA container types
  - Update documentation comments that list supported DA types

### Phase 3: DA Certificate/Data Parsing
- Implement appropriate parsing approach for the DA solution:
  - **Simple parsing**: Extract basic parameters during input processing
  - **Complex parsing**: Full ABI decoding of nested structures
- Create new DA module with parsing logic
- Update `parse_data_availability_info` in `common.ex`:
  - Add new header flag case to route to the new DA module
  - Ensure the function returns the correct DA type atom

### Phase 4: Data Preparation and Import
- Implement `prepare_for_import` functionality based on storage requirements:
  - **Basic storage**: Simple metadata for display
  - **Comprehensive storage**: Multiple record types with supplementary data
  - **Supplementary data collection**: Implement additional data gathering if required
    - **Example**: AnyTrust keyset fetching via `check_if_new_keyset` → `get_keyset_info_from_l1`
    - **RPC operations**: Block number retrieval, event log fetching, data decoding
    - **Third-party integration**: May require external data provider APIs
    - **Caching strategy**: Implement caching to avoid redundant external calls
- Update `common.ex` import logic:
  - Add new DA type to `required_import?` function (if storage is needed)
  - Add pattern matching for new DA type in `prepare_for_import`
  - Include new DA type in `eliminate_conflicts` function
- Implement conflict resolution for both intra-batch and inter-batch scenarios:
  - **Intra-batch deduplication**: Handle multiple batches in same processing chunk referencing same DA blob
  - **Inter-batch resolution**: Implement `resolve_conflict/2` function to handle conflicts with existing database records
    - **Simple deduplication** (Celestia/EigenDA pattern): Exclude candidates when data_key already exists in database
    - **Value-based resolution** (AnyTrust pattern): Compare specific fields (e.g., timeout values) and keep the better record
    - **Custom logic**: Define DA-specific rules for handling duplicate data scenarios

### Phase 5: API Integration
- Add DA-specific rendering functions based on complexity:
  - **Simple rendering**: Direct mapping from single database record
  - **Complex rendering**: Multi-record aggregation with cross-references
- Update API response generation
- Implement DA-specific data retrieval

### Phase 6: Endpoint Extension
- Add new API endpoints for DA-specific lookups to enable backlink integration:
  - **Single-parameter**: `/batches/da/{solution}/:identifier` (AnyTrust, EigenDA)
  - **Multi-parameter**: `/batches/da/{solution}/:param1/:param2` (Celestia)
  - **Purpose**: Allow DA solution explorers to link directly to corresponding batch pages
- Update routing configuration

### Phase 7: Schema Updates
- Update API response schemas
- Add new DA container types to API documentation

## Key Patterns to Follow

### 1. DA Module Structure
Each DA solution module should implement:
- `@enforce_keys` and `defstruct` for DA info structure
- `@type t` type definition
- `parse_batch_accompanying_data/2` function
- `prepare_for_import/2` function  
- `resolve_conflict/2` function

### 2. Common DA Integration Points
**Phase 2 Updates (Type Specifications):**
- Update `@spec` definitions in `common.ex` to include new DA container type
- Update documentation comments listing supported DA types

**Phase 3 Updates (Parsing Logic):**
- Add new header flag case in `parse_data_availability_info` to route to new DA module
- Ensure correct DA type atom is returned

**Phase 4 Updates (Import Logic):**
- Add new DA type to `required_import?` function based on storage needs
- Include new DA type in `prepare_for_import` pattern matching
- Add conflict resolution support in `eliminate_conflicts`

### 3. RPC Parsing Patterns
Two main approaches for handling DA data in `parse_calldata_of_add_sequencer_l2_batch`:
```elixir
# Simple approach: return data as-is
{sequence_number, prev_message_count, new_message_count, data}

# Complex approach: prepend header flag for DA routing
{sequence_number, prev_message_count, new_message_count, <<header_flag>> <> processed_data}
```

### 4. Database Migration Pattern
```elixir
def change do
  execute("ALTER TYPE arbitrum_da_containers_types ADD VALUE 'in_{da_solution}'")
end
```

### 5. API View Pattern
```elixir
case batch.batch_container do
  :in_{da_solution} -> generate_{da_solution}_da_info(batch.number)
  # ... other cases
end
```

### 6. Data Key Calculation
Each DA solution needs a helper function in `da_multi_purpose_record.ex` to calculate the data key used for database storage and lookups. The calculation varies by DA solution:
- **Single-parameter**: Hash of primary identifier
- **Multi-parameter**: Hash of combined parameters

### 7. Conflict Resolution Patterns
The `resolve_conflict/2` function handles duplicate data keys between database and candidate records.

**What are these conflicts?**
There are **two types of conflicts** that must be handled:

**1. Intra-Batch Conflicts** (within current import set):
- **Problem**: Multiple batches in the same processing chunk referencing the same DA blob
- **Issue**: Database uniqueness constraints fail when trying to insert duplicate `data_key` values
- **Solution**: Deduplicate within the current batch before database import
- **Example**: Batches B1 and B2 both reference the same AnyTrust data blob D1

**2. Inter-Batch Conflicts** (current vs existing database):
- **Problem**: Current batch references a DA blob that already exists in database
- **Issue**: Without proper handling, new batch associations can overwrite existing ones
- **Solution**: Check existing database records and resolve conflicts appropriately
- **Example**: Previously imported batch B1 with blob D1, now importing batch B2 with same blob D1

**Common scenarios**: 
- Reprocessing the same batch data during indexer restarts
- Multiple batches referencing identical DA blobs (empty batches scenario)
- Chain reorganizations causing re-import of previously processed DA records

**Resolution strategies:**

**Simple Deduplication Pattern** (Celestia/EigenDA):
- Database record always wins - if `data_key` exists in database, exclude the candidate
- Used when DA records are immutable and duplicates are identical

**Value-Based Resolution Pattern** (AnyTrust):
- Compare specific field values (e.g., timeout) between database and candidate records
- Keep the record with better characteristics (higher timeout = longer data availability)
- Used when DA records can have different quality metrics

## Testing Considerations

When implementing a new DA solution, ensure testing covers:
- Batch discovery and parsing
- **Supplementary data collection** (if applicable):
  - RPC call handling and error scenarios
  - Event log parsing and decoding
  - Caching mechanism functionality
  - Third-party data provider integration
  - Performance impact of additional network calls
- Database import and conflict resolution scenarios:
  - **Intra-batch conflicts**: Multiple batches in same processing chunk with same DA blob
  - **Inter-batch conflicts**: Current batch vs existing database records
  - Value-based conflict resolution (if applicable)
  - Multiple batches referencing the same DA record
  - Chain reorganization scenarios
- API endpoint functionality
- Schema validation
- Error handling for malformed data

## Backward Compatibility

Always ensure that:
- Existing DA solutions continue to work
- Database migrations are non-destructive
- API responses maintain backward compatibility
- New fields are properly nullable where appropriate

## Dependencies

New DA solutions may require:
- Additional Elixir dependencies for cryptographic functions
- ABI encoder/decoder updates
- External service integrations for DA layer communication
- **Supplementary data sources**:
  - Enhanced RPC node access for event log retrieval
  - Third-party data provider APIs for off-chain information
  - Caching infrastructure for performance optimization of external calls

## Implementation Example

The EigenDA implementation ([PR #12915](https://github.com/blockscout/blockscout/pull/12915)) serves as a concrete example of following this systematic approach. The implementation demonstrates:

- **Multi-phase rollout**: From basic method support to full API integration
- **Complex ABI handling**: Nested structures with BlobVerificationProof and BlobHeader
- **Header flag usage**: Custom flag (237) for DA type routing
- **Supplementary data**: While EigenDA doesn't require external data collection like AnyTrust keysets, it showcases complex certificate parsing
- **Database design**: Integration with the `arbitrum_batches_to_da_blobs` table structure
- **API endpoints**: Implementation of `/batches/da/eigenda/:data_hash` reverse lookup

This example illustrates how the abstract patterns described in this guide translate into working code across all the identified file layers.