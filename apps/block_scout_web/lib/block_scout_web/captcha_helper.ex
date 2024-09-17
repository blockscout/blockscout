defmodule BlockScoutWeb.CaptchaHelper do
  @moduledoc """
  A helper for CAPTCHA
  """

  @spec recaptcha_passed?(%{String.t() => String.t()} | nil) :: bool
  def recaptcha_passed?(%{"recaptcha_v3_response" => recaptcha_response}) do
    re_captcha_v3_secret_key = Application.get_env(:block_scout_web, :recaptcha)[:v3_secret_key]
    do_recaptcha_passed?(re_captcha_v3_secret_key, recaptcha_response)
  end

  def recaptcha_passed?(%{"recaptcha_response" => recaptcha_response}) do
    re_captcha_v2_secret_key = Application.get_env(:block_scout_web, :recaptcha)[:v2_secret_key]
    do_recaptcha_passed?(re_captcha_v2_secret_key, recaptcha_response)
  end

  def recaptcha_passed?(_), do: Application.get_env(:block_scout_web, :recaptcha)[:is_disabled]

  def do_recaptcha_passed?(recaptcha_secret_key, recaptcha_response) do
    body = "secret=#{recaptcha_secret_key}&response=#{recaptcha_response}"

    headers = [{"Content-type", "application/x-www-form-urlencoded"}]

    case !Application.get_env(:block_scout_web, :recaptcha)[:is_disabled] &&
           Application.get_env(:block_scout_web, :http_adapter).post(
             "https://www.google.com/recaptcha/api/siteverify",
             body,
             headers,
             []
           ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode!(body) do
          %{"success" => true} = resp -> success?(resp)
          _ -> false
        end

      _ ->
        false
    end
  end

  defp success?(%{"score" => score}) do
    check_recaptcha_v3_score(score)
  end

  defp success?(_resp), do: true

  defp check_recaptcha_v3_score(score) do
    if score >= 0.5 do
      true
    else
      false
    end
  end
end
