# Request Bodies, Security Schemes, and Headers

## Request bodies (POST/PUT/PATCH endpoints)

### The pattern

Request bodies are declared via the `request_body:` key in the `operation/2` macro:

```elixir
operation :my_action,
  summary: "Create a resource",
  description: "Creates a new resource.",
  request_body: my_resource_request_body(),
  parameters: base_params(),
  responses: [...]
```

The value is always a function call returning an `%OpenApiSpex.RequestBody{}` struct.

### Helper function pattern

```elixir
def my_resource_request_body do
  %OpenApiSpex.RequestBody{
    content: %{
      "application/json" => %OpenApiSpex.MediaType{
        schema: %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            field_a: %OpenApiSpex.Schema{type: :string},
            field_b: %OpenApiSpex.Schema{type: :integer}
          },
          required: [:field_a, :field_b]
        }
      }
    }
  }
end
```

### Naming convention

`<descriptive_name>_request_body()` — e.g., `admin_api_key_request_body()`, `audit_report_request_body()`.

### Where to place helpers

- **General/shared**: `schemas/api/v2/general.ex` (auto-imported)
- **Domain-specific**: `schemas/api/v2/<domain>.ex` (must be aliased in the controller)

### Discovering existing request body helpers

Grep for `request_body` in `general.ex` and domain-specific schema files:
```
grep "def.*_request_body" in schemas/api/v2/**/*.ex
```

To see request bodies actually wired into the generated spec (not just defined), run recipe L in `references/oastools-audit-recipes.md`. Useful because grep finds helpers that may not be referenced by any operation.

### How CastAndValidate handles request bodies

After casting, body params are written to `conn.body_params` with **atom keys** (not string keys). Controllers read casted body params like:
```elixir
Map.get(conn.body_params, :email)
```

Body params are NOT merged into `conn.params` — they must be read from `conn.body_params` separately.

### Inline schemas vs module references

Existing request body schemas are defined **inline** within the `%RequestBody{}` struct, not as separate named schema modules. This is the established convention for request bodies in the codebase.

### The library also supports tuple shorthands

`open_api_spex` supports alternative forms for `request_body:`:
1. `%RequestBody{}` struct (what Blockscout uses exclusively)
2. 3-tuple: `{"description", "application/json", SchemaModule}`
3. 4-tuple: `{"description", "application/json", SchemaModule, opts}`

Stick with the `%RequestBody{}` struct to stay consistent with existing code.

### File upload / multipart

Currently, file upload endpoints (like VerificationController) have **no OpenAPI annotations**. There is no established pattern for `"multipart/form-data"` in the codebase. If you need to annotate a multipart endpoint, this would be a new pattern — flag it for discussion.

---

## Security schemes

### Component-level scheme definition

Security schemes are defined in spec aggregator modules, not in controllers. The private API spec (`specs/private.ex`) defines:

```elixir
components: %Components{
  securitySchemes: %{
    "dynamic_jwt" => %SecurityScheme{type: "http", scheme: "bearer", bearerFormat: "JWT"}
  }
}
```

### Per-operation security

The `operation` macro supports a `security:` key:

```elixir
operation :authenticate_via_dynamic,
  summary: "Authenticate via Dynamic JWT",
  security: [%{"dynamic_jwt" => []}],
  responses: [...]
```

This references the scheme defined in components. The `[]` in the value is the list of required scopes (empty = no specific scopes required).

### When to use security

Most public API endpoints don't use `security:`. It's primarily for private/account API endpoints that require authentication. To check if an endpoint needs security:

1. Look at the controller's plugs — does it use an authentication plug?
2. Check the router — is the endpoint in the `AccountRouter` or behind an auth pipeline?
3. Check if the controller reads `conn.assigns.current_user` or similar auth state.

### Discovering existing security patterns

Grep for `security:` in controller files:
```
grep "security:" in controllers/**/*.ex
```

Spec-side lookup: recipe M in `references/oastools-audit-recipes.md`. Empty against the public spec — `security:` is private/account-only. Regenerate against `specs/private.ex` to see auth-bearing endpoints.

---

## Header parameters

### Request headers

Header parameters use `%Parameter{in: :header}`:

```elixir
def my_header_param do
  %Parameter{
    name: :"x-api-key",          # atom with the exact header name (case-insensitive matching)
    in: :header,
    schema: %Schema{type: :string},
    required: false,
    description: "Description of the header"
  }
end
```

`CastAndValidate` reads from `conn.req_headers` with case-insensitive matching — header parameters are cast and validated identically to path/query parameters.

### Discovering existing header params

Grep for `in: :header` in `general.ex`:
```
grep "in: :header" in schemas/api/v2/general.ex
```

### Undeclared cross-cutting headers

Several request headers are consumed at runtime but not declared in OpenAPI specs:
- `show-scam-tokens` — consumed by multiple controllers via `fetch_scam_token_toggle`
- `recaptcha-v2-response` / `recaptcha-v3-response` — consumed by rate limiting
- `x-api-v2-temp-token` — consumed by rate limiting

This is a known gap. When adding these to specs, use the "separate grouped helpers" approach:

```elixir
# Individual helpers in general.ex
def show_scam_tokens_header_param do
  %Parameter{
    name: :"show-scam-tokens", in: :header,
    schema: %Schema{type: :string, enum: ["true", "false"]},
    required: false,
    description: "When 'true', includes tokens flagged as potential scams."
  }
end

# Grouped helper for convenience
def scam_token_header_params, do: [show_scam_tokens_header_param()]
```

Then add to only the operations that actually use them:
```elixir
parameters: base_params() ++ scam_token_header_params() ++ define_paging_params([...])
```

To identify which controllers consume `show-scam-tokens`, grep for `fetch_scam_token_toggle` in controllers.

### Response headers

Response headers use the `OpenApiSpex.Header` struct and are declared via a 4-tuple response form:

```elixir
responses: [
  ok: {"Success description", "application/json", Schemas.MyDomain.Response,
       headers: %{
         "x-ratelimit-limit" => %OpenApiSpex.Header{
           description: "Max requests per window",
           schema: %Schema{type: :integer}
         }
       }}
]
```

Currently, **no response headers are declared** in the codebase (rate-limit, CSRF, temp token headers are all undeclared). This is a known gap. If adding response headers, this 4-tuple form (changing from the standard 3-tuple) is the way to do it.
