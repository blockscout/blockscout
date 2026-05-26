## Trust the runtime over Elixir typespecs

Elixir `@type` and `@spec` declarations are not enforced by the compiler and can drift from the actual runtime values as code evolves. When a typespec disagrees with the struct/map literal at the constructor (or with the return expression of the function), the runtime code is authoritative.

Before drawing conclusions from a typespec — especially when a static-analysis tool (Copilot, CodeRabbit, etc.) cites one as evidence of a bug — verify field names, shapes, and return types by reading the actual constructor or return site. If a mismatch is real, fix the spec, not the runtime code.
