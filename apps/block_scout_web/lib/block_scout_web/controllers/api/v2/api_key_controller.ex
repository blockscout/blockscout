defmodule BlockScoutWeb.API.V2.APIKeyController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelper
  alias Plug.Crypto

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def get_key(conn, %{"recaptcha_response" => recaptcha_response}) do
    helper = Application.get_env(:block_scout_web, :captcha_helper)
    ttl = Application.get_env(:block_scout_web, :api_rate_limit)[:api_v2_token_ttl_seconds]

    with {:recaptcha, true} <- {:recaptcha, helper.recaptcha_passed?(recaptcha_response)} do
      conn
      |> json(key: Crypto.encrypt(conn.secret_key_base, "", %{ip: AccessHelper.conn_to_ip_string(conn)}, max_age: ttl))
    end
  end
end
