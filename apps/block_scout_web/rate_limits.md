# Rate Limits Configuration

Rate limits can be defined in a JSON configuration file `apps/block_scout_web/priv/rate_limit_config.json` or passed to `API_RATE_LIMIT_CONFIG_URL` as a URL to the JSON file.

## Configuration Structure

The JSON configuration is a map where:
- **Keys**: API endpoint paths
- **Values**: Rate limit configuration

### Example Configuration
```json
"api/account/v2/send_otp": {
  "recaptcha_to_bypass_429": true,
  "ip": {
    "period": "1h",
    "limit": 1
  }
}
```

### Path Rules
- Paths should not contain query parameters
- Paths should not contain trailing slashes
- Paths can contain:
  - `*` - Works as a wildcard (matches any path starting from the asterisk)
    - Example: `api/v2/*` matches `api/v2` and `api/v2/addresses`
    - ⚠️ Wildcard `*` allowed only at the end of the path
  - `:param` - Represents a variable parameter in the endpoint path
    - Example: `api/v2/addresses/:param` matches `api/v2/addresses/0x00000..000`
- ⚠️ It's not allowed to use `*` and `:param` simultaneously

### Path Matching Priority
1. Paths without `:param` and `*`
2. Paths with `:param`
3. Paths with `*`

### Default Configuration
The config must contain a `default` key that defines the default API rate limit configuration. This will be used for endpoints that don't match any defined paths in the config.

> **Note**: GraphQL endpoints are out of scope for this config. Their rate limits are based on ENVs: `API_GRAPHQL_RATE_LIMIT_*`

## Rate Limit Options

Each rate limit entry can contain the following keys:

### Rate Limit Methods
- `account_api_key` - Allows using API key emitted in My Account
  > **Important**: When overriding `account_api_key`, ensure your limits are much lower than the default ones
- `whitelisted_ip` - Allows rate limiting by whitelisted IP
- `static_api_key` - Allows rate limiting by static API key
- `temporary_token` - Allows rate limiting by temporary token (cookie) issued by `/api/v2/key`
- `ip` - Allows rate limiting by IP address

### Additional Options
- `cost` - Integer value used to decrease allowed limit (default: `1`)
- `ignore` - If `true`, the endpoint won't be rate limited
- `recaptcha_to_bypass_429` - If `true`, allows passing recaptcha header with response to bypass 429 errors. 
- `bypass_token_scope` - Scope of recaptcha bypass token (currently only supports `token_instance_refetch_metadata`)
- `isolate_rate_limit?` - If `true`, creates a separate rate limit bucket for this endpoint. Instead of using the shared rate limit key, it prepends the endpoint path to create an isolated bucket (e.g., `api/v2/address_127.0.0.1` for the `/api/v2/address` endpoint with IP-based rate limiting).

⚠️ It is recommended to use either `recaptcha_to_bypass_429` or `temporary_token`, not both.

### Rate Limit Option Values
Each rate limit method can have one of these values:
- `true` - Rate limit option is allowed, limits pulled from ENVs
- `false` or omitted - Rate limit option is disabled
- Map with configuration:
  - `limit` - Integer value representing max requests allowed per period
  - `period` - Rate limit time period in [time format](https://docs.blockscout.com/setup/env-variables/backend-env-variables#time-format)

## ReCAPTCHA Implementation

ReCAPTCHA responses should be passed via headers:
- `recaptcha-v2-response` - For V2 captcha
- `recaptcha-v3-response` - For V3 captcha
- `recaptcha-bypass-token` - For non-scoped bypass recaptcha token
- `scoped-recaptcha-bypass-token` - For scoped bypass recaptcha token (currently only supports `token_instance_refetch_metadata` scope)

> **Note**: ReCAPTCHA for `/api/v2/key` endpoint should be sent in the request body.

## Rate Limit Headers

The backend returns informational headers:
- `X-RateLimit-Limit` - Total limit per timeframe
- `X-RateLimit-Remaining` - Remaining requests within current time window
- `X-RateLimit-Reset` - Time to reset rate limits in milliseconds

These headers may return `-1` in case of:
- Internal errors
- `API_NO_RATE_LIMIT_API_KEY` is used
- Rate limits are disabled on the backend
- The endpoint has `"ignore": true` parameter set

### Bypass Options Header
The `bypass-429-option` header indicates how to bypass rate limits:
- `recaptcha` - Use ReCAPTCHA response in headers
- `temporary_token` - Get temporary cookie from `/api/v2/key` endpoint
- `no_bypass` - No way to bypass 429 error
