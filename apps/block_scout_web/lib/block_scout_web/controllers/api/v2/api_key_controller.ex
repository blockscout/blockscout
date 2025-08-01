defmodule BlockScoutWeb.API.V2.APIKeyController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, api_v2_temp_token_key: [:block_scout_web, :api_v2_temp_token_key]

  alias BlockScoutWeb.{AccessHelper, CaptchaHelper}

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(:fetch_cookies, signed: [@api_v2_temp_token_key])

  @doc """
    Function to handle POST requests to `/api/v2/key` endpoint. It expects body with `recaptcha_response`. And puts cookie with temporary API v2 token. Which is handled here: https://github.com/blockscout/blockscout/blob/cd19739347f267d8a6ad81bbba2dbdad08bcc134/apps/block_scout_web/lib/block_scout_web/views/access_helper.ex#L170
  """
  @spec get_key(Plug.Conn.t(), nil | map) :: {:recaptcha, any} | Plug.Conn.t()
  def get_key(conn, params) do
    ttl = div(Application.get_env(:block_scout_web, :api_rate_limit)[:api_v2_token_ttl], 1000)

    with {:recaptcha, true} <- {:recaptcha, CaptchaHelper.recaptcha_passed?(params)} do
      conn
      |> put_resp_cookie(@api_v2_temp_token_key, %{ip: AccessHelper.conn_to_ip_string(conn)},
        max_age: ttl,
        sign: true,
        same_site: "Lax",
        domain: Application.get_env(:block_scout_web, :cookie_domain)
      )
      |> json(%{
        message: "OK"
      })
    end
  end
end
