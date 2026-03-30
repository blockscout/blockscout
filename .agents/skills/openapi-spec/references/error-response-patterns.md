# Error Response Patterns

## Discovery

All custom error response modules are defined in a single file:
`apps/block_scout_web/lib/block_scout_web/schemas/api/v2/error_responses.ex`

Plus one from the `open_api_spex` library itself: `OpenApiSpex.JsonErrorResponse`.

To discover the current set, read `error_responses.ex` and look for `defmodule` declarations. Each module defines a `response/0` helper.

## The response/0 helper pattern

All custom error modules follow this pattern:

```elixir
defmodule NotFoundResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "NotFoundResponse",
    type: :object,
    properties: %{message: %Schema{type: :string, example: "Resource not found"}}
  })

  def response, do: {"Not Found", "application/json", __MODULE__}
end
```

The `response/0` function returns a 3-tuple `{description, content_type, module}` used in operation specs:

```elixir
responses: [
  not_found: NotFoundResponse.response(),
  unprocessable_entity: JsonErrorResponse.response()
]
```

`JsonErrorResponse` (from `open_api_spex`) returns a `%Response{}` struct instead of a tuple. Both forms work in the `operation` macro.

## Status code mapping

The response key in the `responses:` keyword list determines the HTTP status code. Use the atom form:

| Atom key | HTTP status | Typical module |
|---|---|---|
| `:ok` | 200 | (success — use domain schema) |
| `:bad_request` | 400 | `BadRequestResponse` |
| `:unauthorized` | 401 | `UnauthorizedResponse` |
| `:forbidden` | 403 | `ForbiddenResponse` |
| `:not_found` | 404 | `NotFoundResponse` |
| `:unprocessable_entity` | 422 | `JsonErrorResponse` |
| `:not_implemented` | 501 | `NotImplementedResponse` |

To verify the current mapping, read `error_responses.ex` and check the module names and their example messages.

## Auto-aliased modules

Two modules are automatically available in every controller (aliased in `block_scout_web.ex`):

```elixir
alias OpenApiSpex.JsonErrorResponse
alias Schemas.ErrorResponses.ForbiddenResponse
```

All others must be explicitly aliased in the controller:
```elixir
alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.NotFoundResponse
```

To check which are auto-aliased, read the `:controller` quote block in `block_scout_web.ex`.

## When to use which error response

- **`JsonErrorResponse` (422)** — the default for validation errors. `CastAndValidate` returns this automatically when parameter validation fails. Also use when the controller explicitly rejects input as invalid.
- **`NotFoundResponse` (404)** — when the requested resource doesn't exist.
- **`ForbiddenResponse` (403)** — when the request is authenticated but not authorized, or when a required server-side config (like an API key) is missing.
- **`UnauthorizedResponse` (401)** — when authentication is required but missing/invalid. Primarily used in account/private API endpoints.
- **`BadRequestResponse` (400)** — when the request is malformed in a way that isn't a parameter validation error.
- **`NotImplementedResponse` (501)** — when the endpoint exists but the feature is not available.

## Choosing error responses for an operation

Look at the controller action to identify which error paths exist:

1. **Every operation** should include `:unprocessable_entity: JsonErrorResponse.response()` — CastAndValidate can always fail.
2. If the action does a resource lookup (e.g., `Chain.hash_to_transaction`), include `:not_found`.
3. If the action checks authorization (e.g., `AccessHelper.restricted_access?`), include `:forbidden`.
4. If the action requires authentication, include `:unauthorized`.
5. Check `put_status` and `send_resp` calls in the action for other status codes.

Not all runtime error paths need to be in the spec — undeclared status codes (like `:internal_server_error` from rate limiting) are typically treated as infrastructure concerns. But all explicitly handled error cases in the controller action should be declared.

## Custom inline error responses

For one-off error schemas (e.g., a specific error format for a single endpoint), you can use an inline tuple:

```elixir
responses: [
  internal_server_error: {"Error message", "application/json", message_response_schema()}
]
```

Where `message_response_schema()` is a helper that returns an inline schema. Check the controller's existing patterns to see if this is used.
