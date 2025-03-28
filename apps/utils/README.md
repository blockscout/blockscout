# Utils

The Blockscout `Utils` component, provides utility modules that enhance code clarity and maintainability.

- It includes the `CompileTimeEnvHelper` module, which manages compile-time environment variables and selectively recompiles modules when runtime values differ. This module leverages metaprogramming to generate module attributes dynamically.
- The `TokenInstanceHelper` module determines NFT media types by checking file extensions and performing HTTP HEAD requests.
- Additionally, the `Credo.Checks.CompileEnvUsage` custom check enforces that only `CompileTimeEnvHelper` accesses compile-time environment variables by scanning the code's AST for direct usages.
