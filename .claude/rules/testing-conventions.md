## Testing conventions

### Chain-type conditional tests

When a test module or `describe` block should only run for a specific chain type, wrap the **entire** `describe` block (and any related helper functions) with the `if @chain_type` conditional from the outside. Do not place the conditional inside the `describe` block, as this creates empty `describe` blocks in test output for other chain types.

Correct:
```elixir
if @chain_type == :arbitrum do
  describe "/some/arbitrum/endpoint" do
    test "does something", %{conn: conn} do
      # ...
    end
  end

  defp some_helper do
    # ...
  end
end
```

Incorrect:
```elixir
describe "/some/arbitrum/endpoint" do
  if @chain_type == :arbitrum do
    test "does something", %{conn: conn} do
      # ...
    end
  end
end
```
