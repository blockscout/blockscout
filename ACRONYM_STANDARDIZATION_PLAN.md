# Acronym Standardization Implementation Plan

This document provides a comprehensive plan for standardizing acronym representation in module names across the Blockscout codebase.

## Overview

The goal is to standardize well-known acronyms to be fully uppercase in module names, following established Elixir community practices.

## Target Acronyms

- `HTTP` (not `Http`)
- `CSV` (not `Csv`)
- `JSON` (not `Json`)
- `API` (not `Api`)
- `URI` (not `Uri`)
- `UUID` (not `Uuid`)
- `RPC` (not `Rpc`)
- `HTML` (not `Html`)
- `CSS` (not `Css`)
- `SQL` (not `Sql`)
- `XML` (not `Xml`)
- `DB` (not `Db`)

## Completed Changes

### ✅ ZkSync.Utils.Rpc → ZkSync.Utils.RPC
- **Files changed**: 8 files
- **Pattern**: Isolated module with limited dependencies
- **Impact**: Low risk, 15+ references updated successfully
- **Files affected**:
  - `apps/indexer/lib/indexer/fetcher/zksync/utils/rpc.ex` → `RPC.ex`
  - `apps/indexer/test/indexer/fetcher/zksync/utils/rpc_test.exs` → `RPC_test.exs`
  - 6 dependent modules with alias and function call updates

## Pending Changes

### High Impact - Requires Coordinated Effort

#### 1. CsvExport → CSVExport Family
- **Estimated files**: ~15 modules + ~53 references
- **Complexity**: High - affects controllers, views, tests, configuration
- **Key modules**:
  - `Explorer.Chain.CsvExport.Helper` → `Explorer.Chain.CSVExport.Helper`
  - `Explorer.Chain.CsvExport.Address.*` → `Explorer.Chain.CSVExport.Address.*`
  - `BlockScoutWeb.CsvExportController` → `BlockScoutWeb.CSVExportController`
  - `BlockScoutWeb.CsvExportView` → `BlockScoutWeb.CSVExportView`

#### 2. HttpClient → HTTPClient Family
- **Estimated files**: ~10 modules + ~85 references
- **Complexity**: High - affects HTTP client infrastructure
- **Key modules**:
  - `Utils.HttpClient.TeslaHelper` → `Utils.HTTPClient.TeslaHelper`
  - `Utils.HttpClient.HTTPoisonHelper` → `Utils.HTTPClient.HTTPoisonHelper`
  - `Explorer.HttpClient` → `Explorer.HTTPClient`
  - `Explorer.HttpClient.Tesla` → `Explorer.HTTPClient.Tesla`

#### 3. HeavyDbIndexOperation → HeavyDBIndexOperation Family
- **Estimated files**: ~31 modules + configuration references
- **Complexity**: Medium - mostly isolated migration modules
- **Pattern**: All under `Explorer.Migrator.HeavyDbIndexOperation.*`
- **Note**: These modules reference each other, requiring coordinated updates

### Medium Impact

#### 4. Api → API Family
- **Estimated files**: ~20 modules + ~70 references
- **Complexity**: Medium-High - affects API infrastructure
- **Key modules**:
  - `BlockScoutWeb.ApiSpec` → `BlockScoutWeb.APISpec`
  - `BlockScoutWeb.Account.ApiKeyView` → `BlockScoutWeb.Account.APIKeyView`
  - `BlockScoutWeb.API.V2.ApiView` → `BlockScoutWeb.API.V2.APIView`
  - Various router and controller modules

## Implementation Strategy

### Phase 1: Documentation and Guidelines ✅
- [x] Update CONTRIBUTING.md with naming conventions
- [x] Add migration strategy guidelines
- [x] Complete one small example (ZkSync RPC)

### Phase 2: Isolated Modules (Recommended Next)
- [ ] Complete remaining HeavyDbIndexOperation modules
  - These are mostly isolated migration modules
  - Update all 31 modules in coordinated commits
  - Update configuration references

### Phase 3: Infrastructure Modules (Major Effort)
- [ ] HttpClient family (coordinate with team)
- [ ] CsvExport family (coordinate with team)
- [ ] Api family (coordinate with team)

## Implementation Guidelines

### For Each Module Group:
1. **Prepare**: Identify all files and references
2. **Create**: New files with correct naming
3. **Update**: Module definitions in new files
4. **Update**: All alias statements
5. **Update**: All function calls and references
6. **Update**: Configuration files
7. **Update**: Tests
8. **Update**: Documentation and comments
9. **Remove**: Old files
10. **Test**: Ensure no breakage

### Risk Mitigation:
- Work in small, isolated groups
- Use systematic find/replace operations
- Test each group thoroughly before proceeding
- Coordinate with team for high-impact changes
- Consider feature flags for major infrastructure changes

## Reference Commands

### Finding modules to update:
```bash
# Find modules with lowercase acronyms
find . -name "*.ex" | xargs grep "defmodule.*\.\(Csv\|Http\|Json\|Api\|Uri\|Uuid\|Rpc\|Html\|Css\|Sql\|Xml\|Db\)[A-Z]"

# Count references to a pattern
grep -r "CsvExport" --include="*.ex" --include="*.exs" . | wc -l

# Find files matching a pattern
find . -name "*csv_export*" -type f
```

### Systematic updates:
```bash
# Update function calls in files
sed -i 's/Rpc\./RPC\./g' target_file.ex

# Update alias statements
sed -i 's/alias Module\.Old/alias Module\.New/g' target_file.ex
```

## Status Tracking

- ✅ **Completed**: ZkSync.Utils.RPC (1 module group)
- 🔄 **In Progress**: Documentation and planning
- ⏳ **Pending**: ~75+ modules across 4 major groups

## Notes

- This is a significant undertaking that affects core infrastructure
- Changes should be coordinated with the development team
- Consider doing this work during a low-activity period
- Each phase should be thoroughly tested before proceeding
- Some changes may require database migrations or configuration updates