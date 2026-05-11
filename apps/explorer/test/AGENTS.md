# Explorer Test Conventions

## Application config in tests

When overriding `Application` config in test `setup`, use `Keyword.merge/2` with the initial config — don't replace the entire keyword list. Replacing drops keys that other code paths rely on.

```elixir
# Good
initial = Application.get_env(:explorer, SomeModule)
Application.put_env(:explorer, SomeModule, Keyword.merge(initial, key: :override))

# Bad — drops all other keys
Application.put_env(:explorer, SomeModule, key: :override)
```

Handle potentially nil initial configs with `initial || []`.
