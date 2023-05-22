defmodule BlockScoutWeb.CaptchaHelper do
  @moduledoc """
  A helper for CAPTCHA
  """

  @callback recaptcha_passed?(String.t() | nil) :: bool
  @spec recaptcha_passed?(String.t() | nil) :: bool
  def recaptcha_passed?(nil), do: false

  def recaptcha_passed?(recaptcha_response) do
    re_captcha_v2_secret_key = Application.get_env(:block_scout_web, :recaptcha)[:v2_secret_key]
    re_captcha_v3_secret_key = Application.get_env(:block_scout_web, :recaptcha)[:v3_secret_key]
    re_captcha_secret_key = re_captcha_v2_secret_key || re_captcha_v3_secret_key
    body = "secret=#{re_captcha_secret_key}&response=#{recaptcha_response}"

    headers = [{"Content-type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://www.google.com/recaptcha/api/siteverify", body, headers, []) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode!(body) do
          %{"success" => true} = resp -> is_success?(resp)
          _ -> false
        end

      _ ->
        false
    end
  end

  defp is_success?(%{"score" => score}) do
    check_recaptcha_v3_score(score)
  end

  defp is_success?(_resp), do: true

  defp check_recaptcha_v3_score(score) do
    if score >= 0.5 do
      true
    else
      false
    end
  end
end
