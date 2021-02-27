defmodule BlockScoutWeb.Faucet.CaptchaController do
  use BlockScoutWeb, :controller

  alias Plug.Conn

  def index(conn, %{"captchaResponse" => captcha_response, "type" => "JSON"}) do
    case validate_captcha_response(captcha_response) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Conn.resp(conn, status_code, body)
    end
  end

  def validate_captcha_response(captcha_response) do
    body =
      "secret=#{Application.get_env(:block_scout_web, :faucet)[:h_captcha_secret_key]}&response=#{captcha_response}"

    headers = [{"Content-type", "application/x-www-form-urlencoded"}]

    HTTPoison.post("https://hcaptcha.com/siteverify", body, headers, [])
  end
end
