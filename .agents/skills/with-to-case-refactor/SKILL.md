---
name: with-to-case-refactor
description: Replace `with` expressions that contain only a single `<-` clause and an `else` branch with a `case` expression. This addresses the Credo warning "with contains only one <- clause and an else branch, consider using case instead" and produces cleaner, more idiomatic Elixir code.
---

## Overview

Elixir's `with` construct is designed for chaining multiple pattern-matching steps. When only one `<-` clause is present alongside an `else` branch, `with` adds no value over a plain `case`. Credo flags this as:

```
[R] → `with` contains only one <- clause and an `else` branch, consider using `case` instead
```

Always prefer `case` in this situation.

## When to Use

- When a `with` expression has exactly one `<-` clause and one or more `else` arms.
- When refactoring code to address the Credo `Credo.Check.Refactor.WithClauses` warning.

## Anti-Pattern (Avoid)

```elixir
# ❌ BAD: single-clause with/else — should be a case
with {:ok, response} <- json_rpc(params, opts) do
  process(response)
else
  {:error, reason} ->
    Logger.error("RPC failed: #{inspect(reason)}")
    :error
end
```

```elixir
# ❌ BAD: single-clause with/else wrapping a nested case
with {:ok, response} <- json_rpc(params, opts) do
  case parse(response) do
    {:ok, value} -> value
    _            -> :error
  end
else
  {:error, reason} ->
    Logger.error("RPC failed: #{inspect(reason)}")
    :error
end
```

## Best Practice (Use Instead)

```elixir
# ✅ GOOD: flat case replaces with/else
case json_rpc(params, opts) do
  {:ok, response} ->
    process(response)

  {:error, reason} ->
    Logger.error("RPC failed: #{inspect(reason)}")
    :error
end
```

```elixir
# ✅ GOOD: nested case is fine when the outer with is replaced
case json_rpc(params, opts) do
  {:ok, response} ->
    case parse(response) do
      {:ok, value} -> value
      _            -> :error
    end

  {:error, reason} ->
    Logger.error("RPC failed: #{inspect(reason)}")
    :error
end
```

## Transformation Rules

1. Move the expression on the right-hand side of `<-` to become the subject of `case`.
2. Turn the left-hand side of `<-` into the matching branch of `case`.
3. Move the body of the `with` block as the body of that `case` branch.
4. Move each arm of the `else` block as additional `case` branches.
5. Remove the `with`/`else`/`end` wrapper.

## Real-World Example (from this codebase)

### Before

```elixir
with {:ok, response} <-
       params
       |> Map.merge(%{id: 0})
       |> Nonce.request()
       |> json_rpc(json_rpc_named_arguments) do
  case Nonce.from_response(%{id: 0, result: response}, id_to_params) do
    {:ok, %{nonce: 0}} -> handle_zero_nonce(...)
    {:ok, %{nonce: nonce}} when nonce > 0 -> handle_nonzero_nonce(...)
    _ -> retry(...)
  end
else
  {:error, reason} ->
    Logger.error("Error: #{inspect(reason)}")
    retry(...)
end
```

### After

```elixir
case params
     |> Map.merge(%{id: 0})
     |> Nonce.request()
     |> json_rpc(json_rpc_named_arguments) do
  {:ok, response} ->
    case Nonce.from_response(%{id: 0, result: response}, id_to_params) do
      {:ok, %{nonce: 0}} -> handle_zero_nonce(...)
      {:ok, %{nonce: nonce}} when nonce > 0 -> handle_nonzero_nonce(...)
      _ -> retry(...)
    end

  {:error, reason} ->
    Logger.error("Error: #{inspect(reason)}")
    retry(...)
end
```

## Notes

- If the `with` has **two or more** `<-` clauses, keep it as `with`; this refactor only applies to the single-clause case.
- If there is no `else` branch at all, `with` is also acceptable for a single clause — but a `case` is still clearer and preferred.
- After refactoring, run `mix format` to ensure correct indentation.
