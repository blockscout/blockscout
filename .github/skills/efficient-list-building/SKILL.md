---
name: efficient-list-building
description: Build lists efficiently using prepend operations and Enum.reverse/1 instead of append. Appending to lists is O(n) while prepending is O(1). Use [head | tail] notation and reverse at the end when order matters.
---

## Overview

In Elixir (and Erlang), appending to a list using `++` is an expensive O(n) operation because it requires traversing the entire left list. Prepending using `[head | tail]` is O(1) and much more efficient. When building lists in a specific order, prepend elements and call `Enum.reverse/1` once at the end.

## When to Use

- When accumulating results in `Enum.reduce/3` or recursive functions
- When building lists incrementally in loops or iterations
- When order matters but you're currently appending one item at a time
- When Credo warns: "Appending a single item to a list is inefficient"
- When refactoring code with performance bottlenecks in list building

## Anti-Patterns (Avoid These)

```elixir
# ❌ BAD: O(n) append operation in each iteration
Enum.reduce(items, [], fn item, acc ->
  acc ++ [process(item)]
end)

# ❌ BAD: Expensive in a reduce - O(n) for each append
Enum.reduce(block_ranges, {[], []}, fn range, {parts, params} ->
  {[part | parts], params ++ [value1, value2]}
end)

# ❌ BAD: Multiple appends in recursion
def build_list([head | tail], acc) do
  build_list(tail, acc ++ [transform(head)])
end
def build_list([], acc), do: acc

# ❌ BAD: Binary string concatenation with ++
# ++ is for lists (charlists), not binaries like ""
Enum.reduce(fragments, "", fn frag, acc ->
  acc ++ frag
end)
```

## Best Practices (Use These)

```elixir
# ✅ GOOD: O(1) prepend + O(n) reverse once at the end
items
|> Enum.reduce([], fn item, acc ->
  [process(item) | acc]
end)
|> Enum.reverse()

# ✅ GOOD: Prepend params in reverse order, then reverse once
Enum.reduce(block_ranges, {[], []}, fn range, {parts, params} ->
  {[part | parts], [value2, value1 | params]}
end)
|> then(fn {parts, params} -> {Enum.reverse(parts), Enum.reverse(params)} end)

# ✅ GOOD: Prepend in recursion, reverse at top level
defp build_list_helper([head | tail], acc) do
  build_list_helper(tail, [transform(head) | acc])
end
defp build_list_helper([], acc), do: acc

def build_list(items) do
  items
  |> build_list_helper([])
  |> Enum.reverse()
end

# ✅ GOOD: Use IO lists for binary/string building
# Prepend fragments, then convert to binary (proper iolist structure)
fragments
|> Enum.reduce([], fn frag, acc -> [frag | acc] end)
|> Enum.reverse()
|> IO.iodata_to_binary()

# ✅ GOOD: Binary concatenation with <>
Enum.reduce(fragments, "", fn frag, acc ->
  acc <> frag
end)
```

## Example Fix

### Before (Inefficient):
```elixir
{sql_parts, params} =
  Enum.reduce(block_ranges, {[], []}, fn
    first..last//_, {parts, acc_params} ->
      from = min(first, last)
      to = max(first, last)
      part = "SELECT * FROM generate_series($1, $2)"
      
      # O(n) append for each iteration
      {[part | parts], acc_params ++ [from, to]}
  end)

# sql_parts already reversed, but params not
use_query(sql_parts |> Enum.reverse(), params)
```

### After (Optimized):
```elixir
{sql_parts, params} =
  Enum.reduce(block_ranges, {[], []}, fn
    first..last//_, {parts, acc_params} ->
      from = min(first, last)
      to = max(first, last)
      part = "SELECT * FROM generate_series($1, $2)"
      
      # O(1) prepend (note reverse order: to, from)
      {[part | parts], [to, from | acc_params]}
  end)

# Both need reversing now - but only once, not in every iteration
use_query(Enum.reverse(sql_parts), Enum.reverse(params))
```

## Performance Comparison

| Operation | Time Complexity | Description |
|-----------|-----------------|-------------|
| `list ++ [item]` | O(n) | Traverses entire left list to append |
| `[item \| list]` | O(1) | Prepends without traversal |
| `Enum.reverse(list)` | O(n) | Single traversal at the end |

### Total Cost Example

**Building a 1000-item list:**
- Appending in loop: O(1) + O(2) + O(3) + ... + O(1000) = **O(n²)** ≈ 500,000 operations
- Prepending + reverse: O(1) × 1000 + O(1000) = **O(n)** ≈ 2,000 operations

The prepend approach is **~250x faster** for 1000 items!

## Common Scenarios

### Accumulating in Reduce

```elixir
# ❌ BAD
numbers |> Enum.reduce([], fn n, acc -> acc ++ [n * 2] end)

# ✅ GOOD  
numbers 
|> Enum.reduce([], fn n, acc -> [n * 2 | acc] end)
|> Enum.reverse()
```

### Building Multiple Lists

```elixir
# ❌ BAD
Enum.reduce(items, {[], []}, fn item, {list1, list2} ->
  {list1 ++ [process1(item)], list2 ++ [process2(item)]}
end)

# ✅ GOOD
items
|> Enum.reduce({[], []}, fn item, {list1, list2} ->
  {[process1(item) | list1], [process2(item) | list2]}
end)
|> then(fn {list1, list2} -> {Enum.reverse(list1), Enum.reverse(list2)} end)
```

### Recursive List Building

```elixir
# ❌ BAD
def recursive_build([h | t], acc), do: recursive_build(t, acc ++ [transform(h)])
def recursive_build([], acc), do: acc

# ✅ GOOD
def recursive_build(list), do: recursive_build_helper(list, []) |> Enum.reverse()

defp recursive_build_helper([h | t], acc), do: recursive_build_helper(t, [transform(h) | acc])
defp recursive_build_helper([], acc), do: acc
```

### String/Binary Building

```elixir
# ❌ BAD: ++ doesn't work for binaries, only lists
fragments |> Enum.reduce("", fn frag, acc -> acc ++ frag end)

# ✅ GOOD: Use <> for binaries
fragments |> Enum.reduce("", fn frag, acc -> acc <> frag end)

# ✅ BETTER: Use IO lists (more efficient for many fragments)
fragments
|> Enum.reduce([], fn frag, acc -> [frag | acc] end)
|> Enum.reverse()
|> IO.iodata_to_binary()
```

## Important Note on iolist Structure

When building IO lists (used for efficient binary/string construction), ensure proper structure:

```elixir
# ❌ WRONG: [acc | frag] doesn't create a proper iolist
# This conses acc as the head with frag as the tail - fails when frag is binary
Enum.reduce(fragments, [], fn frag, acc -> [acc | frag] end)

# ✅ CORRECT: [frag | acc] - proper cons structure
# Then reverse to get correct order or use Enum.reverse()
Enum.reduce(fragments, [], fn frag, acc -> [frag | acc] end)
|> Enum.reverse()
|> IO.iodata_to_binary()
```

## Notes

- If order doesn't matter, you can skip `Enum.reverse/1` entirely
- For string/binary building, `<>` works but can be O(n²) in a loop; IO lists are better
- `Enum.map/2` already handles this efficiently internally
- When prepending multiple items, add them in reverse order: `[item2, item1 | acc]`

## Tools and Warnings

**Credo Warning:**
```
Appending a single item to a list is inefficient, use `[head | tail]` 
notation (and `Enum.reverse/1` when order matters).
```

**Fix:** Replace `list ++ [item]` with `[item | list]` and add `Enum.reverse/1` at the end if order matters.

## References

- [Elixir List documentation](https://hexdocs.pm/elixir/List.html)
- [Kernel.++/2 performance characteristics](https://hexdocs.pm/elixir/Kernel.html#++/2)
- [Efficient list building in functional languages](https://learnyousomeerlang.com/starting-out-for-real#lists)
