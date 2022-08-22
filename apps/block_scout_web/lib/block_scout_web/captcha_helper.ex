defmodule BlockScoutWeb.CaptchaHelper do
  @moduledoc """
  A helper for CAPTCHA
  """

  @callback recaptcha_passed?(String.t() | nil) :: bool
  @spec recaptcha_passed?(String.t() | nil) :: bool
  def recaptcha_passed?(nil), do: false

  def recaptcha_passed?(recaptcha_response) do
    re_captcha_secret_key = Application.get_env(:block_scout_web, :re_captcha_secret_key)
    body = "secret=#{re_captcha_secret_key}&response=#{recaptcha_response}"

    headers = [{"Content-type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://www.google.com/recaptcha/api/siteverify", body, headers, []) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode!(body) do
          %{"success" => true} -> true
          _ -> false
        end

      _ ->
        false
    end
  end
end
