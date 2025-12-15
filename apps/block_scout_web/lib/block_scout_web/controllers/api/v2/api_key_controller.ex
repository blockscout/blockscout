defmodule BlockScoutWeb.API.V2.APIKeyController do
  use BlockScoutWeb, :controller

  use Utils.CompileTimeEnvHelper,
    api_v2_temp_token_cookie_key: [:block_scout_web, :api_v2_temp_token_cookie_key],
    api_v2_temp_token_header_key: [:block_scout_web, :api_v2_temp_token_header_key]

  alias BlockScoutWeb.{AccessHelper, CaptchaHelper}
  alias Plug.Crypto

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(:fetch_cookies, signed: [@api_v2_temp_token_cookie_key])

  @doc """
  Handles POST requests to `/api/v2/key` endpoint to generate a temporary API v2 token after CAPTCHA verification.

  The function verifies the CAPTCHA response and, upon successful verification,
  generates a temporary API v2 token tied to the client's IP address. The token
  is delivered either as a signed response header or as a signed cookie,
  depending on the `in_header` parameter. The token is validated by
  `BlockScoutWeb.RateLimit.get_ui_v2_token/2`.

  ## Parameters
  - `conn`: The connection struct.
  - `params`: A map that may contain:
    * `"recaptcha_bypass_token"`, `"recaptcha_v3_response"`, or
      `"recaptcha_response"` for CAPTCHA verification
    * `"in_header"` - if set to `"true"`, the token is placed in a response
      header; otherwise, it is placed in a cookie

  ## Returns
  - A connection struct with a JSON response `{"message": "OK"}` and either:
    * A signed token in the response header (if `params["in_header"]` is
      `"true"`)
    * A signed token in a cookie (otherwise)
  - `{:recaptcha, false}` if CAPTCHA verification fails.
  """
  @spec get_key(Plug.Conn.t(), nil | map) :: {:recaptcha, any} | Plug.Conn.t()
  def get_key(conn, params) do
    ttl = div(Application.get_env(:block_scout_web, :api_rate_limit)[:api_v2_token_ttl], 1000)

    with {:recaptcha, true} <- {:recaptcha, CaptchaHelper.recaptcha_passed?(params)} do
      params["in_header"]
      |> case do
        "true" ->
          put_resp_header(
            conn,
            @api_v2_temp_token_header_key,
            Crypto.sign(
              conn.secret_key_base,
              @api_v2_temp_token_header_key <> "-header",
              %{ip: AccessHelper.conn_to_ip_string(conn)},
              keys: Plug.Keys,
              max_age: ttl
            )
          )

        _ ->
          put_resp_cookie(conn, @api_v2_temp_token_cookie_key, %{ip: AccessHelper.conn_to_ip_string(conn)},
            max_age: ttl,
            sign: true,
            same_site: "Lax",
            domain: Application.get_env(:block_scout_web, :cookie_domain)
          )
      end
      |> json(%{
        message: "OK"
      })
    end
  end
end
