---
name: alias-nested-modules
description: Define module aliases at the top of the file instead of using fully qualified nested module names in function bodies. Improves code readability and maintainability while addressing Credo style warnings.
---

## Overview

When using modules with long, nested names multiple times in your code, Elixir's `alias` directive allows you to create shorter references at the top of the module. This improves code readability, reduces duplication, and makes refactoring easier. Credo warns when nested modules are called directly in function bodies instead of being aliased.

## When to Use

- When calling functions from deeply nested modules (3+ levels)
- When the same nested module is referenced multiple times
- When addressing Credo warning: "Nested modules could be aliased at the top of the invoking module"
- When improving code readability and reducing line length
- During code reviews or refactoring for consistency

## Anti-Patterns (Avoid These)

```elixir
defmodule MyApp.Service do
  # ❌ BAD: No aliases, long nested module names in functions
  
  def fetch_data do
    MyApp.ExternalServices.API.Client.fetch()
  end
  
  def process_data(data) do
    MyApp.ExternalServices.API.Parser.parse(data)
  end
  
  def validate_result(result) do
    MyApp.ExternalServices.API.Validator.validate(result)
  end
end

# ❌ BAD: Nested module call in private function
defmodule Explorer.Chain.Metrics.Queries.IndexerMetrics do
  defp multichain_search_enabled? do
    Explorer.MicroserviceInterfaces.MultichainSearch.enabled?()
  end
end
```

## Best Practices (Use These)

```elixir
defmodule MyApp.Service do
  # ✅ GOOD: Aliases defined at module top
  alias MyApp.ExternalServices.API.Client
  alias MyApp.ExternalServices.API.Parser
  alias MyApp.ExternalServices.API.Validator
  
  def fetch_data do
    Client.fetch()
  end
  
  def process_data(data) do
    Parser.parse(data)
  end
  
  def validate_result(result) do
    Validator.validate(result)
  end
end

# ✅ GOOD: Module aliased at the top
defmodule Explorer.Chain.Metrics.Queries.IndexerMetrics do
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  
  defp multichain_search_enabled? do
    MultichainSearch.enabled?()
  end
end
```

## Alias Patterns

### Basic Alias

```elixir
# ✅ Simple alias - uses last segment as the name
alias MyApp.Services.EmailService

EmailService.send()
```

### Multiple Related Aliases

```elixir
# ✅ Group related modules
alias MyApp.Models.{User, Post, Comment}

User.find(id)
Post.create(attrs)
Comment.list_by_post(post_id)
```

### Custom Alias Name

```elixir
# ✅ Use custom name to avoid conflicts or for clarity
alias MyApp.External.API.Client, as: ExternalClient
alias MyApp.Internal.API.Client, as: InternalClient

ExternalClient.request()
InternalClient.request()
```

### Alias in Pattern

```elixir
# ✅ Common aliasing pattern for nested structures
alias MyApp.Services.{
  Authentication,
  Authorization,
  Notification
}
```

## Example Fix

### Before (Credo Warning):
```elixir
defmodule Explorer.Chain.Metrics.Queries.IndexerMetrics do
  import Ecto.Query
  alias Ecto.Adapters.SQL
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Repo

  # No alias for MultichainSearch

  defp multichain_search_enabled? do
    # ⚠️ Credo warning: Nested modules could be aliased
    Explorer.MicroserviceInterfaces.MultichainSearch.enabled?()
  end
  
  defp check_feature_x do
    Explorer.MicroserviceInterfaces.MultichainSearch.feature_x_enabled?()
  end
end
```

### After (Credo Clean):
```elixir
defmodule Explorer.Chain.Metrics.Queries.IndexerMetrics do
  import Ecto.Query
  alias Ecto.Adapters.SQL
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Repo

  # ✅ Module aliased at top, cleaner function bodies
  
  defp multichain_search_enabled? do
    MultichainSearch.enabled?()
  end
  
  defp check_feature_x do
    MultichainSearch.feature_x_enabled?()
  end
end
```

## Benefits

1. **Readability**: Shorter, clearer function bodies
2. **Maintainability**: Change the module path in one place
3. **Performance**: No runtime difference (aliases are compile-time)
4. **Consistency**: Follows Elixir community conventions
5. **Refactoring**: Easier to reorganize module structure

## When NOT to Alias

```elixir
# ✅ OK: Single use of a module - aliasing adds noise
def one_time_call do
  MyApp.RarelyUsed.Module.function()
end

# ✅ OK: Very short module name
def use_map do
  Map.get(data, :key)
end

# ✅ OK: Kernel or Elixir standard library
def use_enum do
  Enum.map(list, &process/1)
end
```

## Ordering Aliases

Follow this conventional order for imports and aliases:

```elixir
defmodule MyApp.Service do
  # 1. Use statements
  use GenServer
  
  # 2. Import statements
  import Ecto.Query
  
  # 3. Alias statements (alphabetically)
  alias Ecto.Adapters.SQL
  alias MyApp.Models.User
  alias MyApp.Services.{EmailService, SmsService}
  
  # 4. Require statements
  require Logger
end
```

## Common Credo Warnings

### Warning Message
```
[D] ↘ Nested modules could be aliased at the top of the invoking module.
```

### How to Fix
1. Identify the nested module being called directly
2. Add an `alias` directive at the top of the module
3. Update all references to use the aliased name
4. Run `mix credo` to verify the warning is resolved

## Related Credo Rules

- `Credo.Check.Readability.AliasOrder` - Checks alias alphabetical order
- `Credo.Check.Readability.ModuleDoc` - Ensures modules have documentation
- `Credo.Check.Design.AliasUsage` - Reports nested module usage

## Additional Resources

- [Elixir Alias documentation](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#alias/2)
- [Elixir Style Guide - Aliases](https://github.com/christopheradams/elixir_style_guide#alias-import-use)
- [Credo configuration](https://hexdocs.pm/credo/config_file.html)
