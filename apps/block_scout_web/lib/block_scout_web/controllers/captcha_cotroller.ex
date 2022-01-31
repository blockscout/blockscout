defmodule BlockScoutWeb.CaptchaController do
  use BlockScoutWeb, :controller

  alias Plug.Conn

  def index(conn, %{"captchaResponse" => captcha_response, "type" => "JSON"}) do
    body = "secret=#{Application.get_env(:block_scout_web, :re_captcha_secret_key)}&response=#{captcha_response}"

    headers = [{"Content-type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://www.google.com/recaptcha/api/siteverify", body, headers, []) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Conn.resp(conn, status_code, body)
    end
  end
end
