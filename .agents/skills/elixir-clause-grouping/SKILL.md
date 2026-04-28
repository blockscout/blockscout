---
name: elixir-clause-grouping
description: Use when refactoring Elixir multi-clause functions, extracting helper functions, or fixing Credo readability warnings caused by placing `defp` helpers between clauses of the same function. Keeps function clauses contiguous and moves helpers below the full clause group.
---

## Overview

In Elixir modules, all clauses of the same function should stay together. Inserting a `defp` helper between clauses of a `def` or `defp` makes the function harder to read and can trigger Credo readability warnings. When shared logic needs to be extracted, keep the original clause group contiguous and place the helper after the full group.

This also applies to Phoenix view modules that define many `render/2` clauses with different templates: all `render/2` clauses still belong to the same function and must be contiguous.

## When to Use

- When refactoring a multi-clause `def` or `defp`
- When extracting duplicated logic from multiple function clauses
- When addressing Credo warnings about clause grouping or readability
- When editing controller, view, or context modules with several clauses of the same function
- During review when a helper was added in the middle of another function's clauses
- When editing Phoenix `render/2` clauses and introducing helper functions nearby
- When adding any `defp` between two definitions that share the same function name/arity
- When you see compiler output like: `clauses with the same name and arity ... should be grouped together`

## Core Rule

- Keep all clauses of the same function contiguous
- Do not place `defp` helpers between clauses of another function
- Extract shared logic into a helper placed after the full clause group
- Before finishing edits, scan up/down around each new helper and verify no same-name/same-arity clauses are split
- In view modules, keep all `render/2` clauses contiguous even if clause heads match different template strings

## Anti-Pattern

```elixir
def decoded_input_data(%Transaction{to_address: nil}, _, _, _, _), do: {:error, :no_to_address}

defp decode_input_data_with_fallback(data, abi, input, hash, skip_sig_provider?, options, methods_map, abi_map) do
  ...
end

def decoded_input_data(%Transaction{to_address: %NotLoaded{}}, _, _, _, _), do: {:error, :contract_not_verified, []}
```

This splits the `decoded_input_data/5` clause group and makes the function harder to scan.

## Preferred Pattern

```elixir
def decoded_input_data(%Transaction{to_address: nil}, _, _, _, _), do: {:error, :no_to_address}

def decoded_input_data(%Transaction{to_address: %NotLoaded{}}, _, _, _, _), do: {:error, :contract_not_verified, []}

def decoded_input_data(%Transaction{to_address: %{smart_contract: smart_contract}} = transaction, skip_sig_provider?, options, methods_map, abi_map) do
  ...
end

defp decode_input_data_with_fallback(data, abi, input, hash, skip_sig_provider?, options, methods_map, abi_map) do
  ...
end
```

## Refactoring Checklist

1. Identify every clause of the function being edited.
2. Keep those clauses adjacent to each other.
3. Extract shared logic only after the full clause group.
4. Re-check that no unrelated `def` or `defp` appears inside the group.
5. Run formatting after the refactor.
6. For Phoenix views, explicitly verify all `render/2` clauses are contiguous (not only clauses for the same template).
7. If you add a helper used by `render/2`, place it after the last `render/2` clause in the module.

## Trigger Cues

- Compiler warning: `clauses with the same name and arity ... should be grouped together`
- Credo warning about grouping/splitting function clauses
- A diff that inserts `defp` between two `def render(` declarations

## Notes

- This applies to both public and private multi-clause functions.
- If a helper is only used by one clause group, place it immediately after that group.
- Preserving clause grouping is preferred even when the extracted helper is small.