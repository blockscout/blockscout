---
name: compare-against-empty-list
description: Optimize list checks by comparing against empty lists instead of using length/1. Avoid expensive list traversal operations when checking if a list is empty or has elements. Use pattern matching or empty list comparison for better performance.
---

## Overview

Using `length/1` to check if a list is empty or has elements is computationally expensive because it requires traversing the entire list to count all elements. In Elixir, you should use pattern matching or direct comparison with empty lists `[]` for better performance.

## When to Use

- When checking if a list is empty: `list == []` or `list != []`
- When verifying a list has elements
- When writing guard clauses that test list conditions
- When refactoring code that uses `length(list) > 0` or `length(list) == 0`
- Addressing Credo warnings about expensive `length/1` usage

## Anti-Patterns (Avoid These)

```elixir
# ❌ BAD: Expensive - traverses entire list
def fetch_block_consensus(block_hashes) when is_list(block_hashes) and length(block_hashes) > 0 do
  # ...
end

# ❌ BAD: Checks length unnecessarily
if length(list) == 0 do
  []
else
  process(list)
end

# ❌ BAD: Expensive guard
def process(items) when length(items) > 0 do
  # ...
end
```

## Best Practices (Use These)

```elixir
# ✅ GOOD: Pattern matching - O(1) operation
def fetch_block_consensus([]), do: %{}
def fetch_block_consensus(block_hashes) when is_list(block_hashes) do
  # ...
end

# ✅ GOOD: Direct comparison with empty list
if list == [] do
  []
else
  process(list)
end

# ✅ GOOD: Pattern matching in function head
def process([]), do: :empty
def process([_head | _tail] = items) do
  # Has at least one element
end

# ✅ GOOD: Using Enum.empty?/1 for clarity
if Enum.empty?(list) do
  []
else
  process(list)
end
```

## Example Fix

### Before (Expensive):
```elixir
def fetch_block_consensus(block_hashes) when is_list(block_hashes) and length(block_hashes) > 0 do
  __MODULE__
  |> where([b], b.hash in ^block_hashes)
  |> select([b], {b.hash, b.consensus})
  |> Repo.all()
  |> Map.new()
end

def fetch_block_consensus(_), do: %{}
```

### After (Optimized):
```elixir
def fetch_block_consensus([]), do: %{}
def fetch_block_consensus(block_hashes) when is_list(block_hashes) do
  __MODULE__
  |> where([b], b.hash in ^block_hashes)
  |> select([b], {b.hash, b.consensus})
  |> Repo.all()
  |> Map.new()
end
```

## Performance Comparison

| Operation | Time Complexity | Description |
|-----------|----------------|-------------|
| `length(list) > 0` | O(n) | Traverses entire list |
| `list == []` | O(1) | Immediate comparison |
| `[_ \| _] = list` | O(1) | Pattern match first element |
| `Enum.empty?(enumerable)` | O(1) for lists; short-circuits for many enumerables | May evaluate enumerable until first element; can trigger side effects |

## Common Use Cases

### 1. Guard Clauses
```elixir
# ✅ Use pattern matching
def process([]), do: :empty
def process(list) when is_list(list), do: do_work(list)
```

### 2. Conditional Logic
```elixir
# ✅ Compare with empty list
case items do
  [] -> :no_items
  [single] -> {:single, single}
  many -> {:many, many}
end
```

### 3. Function Arguments Validation
```elixir
# ✅ Multiple function clauses
def validate([]), do: {:error, :empty}
def validate(list) when is_list(list), do: {:ok, list}
```

## Key Takeaways

- **Never use `length(list)` just to check emptiness** - it's O(n) operation
- **Pattern matching is your friend** - it's O(1) and idiomatic Elixir
- **Use `== []` or `!= []`** for explicit empty checks
- **`Enum.empty?/1` is acceptable** - it's optimized and readable
- **Credo will warn you** - take these warnings seriously for performance

## Related Credo Rules

- `Credo.Check.Refactor.LengthForEmptyCheck`
- `Credo.Check.Warning.ExpensiveEmptyEnumCheck`