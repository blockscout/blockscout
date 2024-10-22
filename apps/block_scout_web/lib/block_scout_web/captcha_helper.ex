defmodule BlockScoutWeb.CaptchaHelper do
  @moduledoc """
  A helper for CAPTCHA
  """

  alias Explorer.Helper

  @doc """
  Verifies if the CAPTCHA challenge has been passed based on the provided parameters.

  This function handles both reCAPTCHA v3 and v2 responses, as well as cases where
  CAPTCHA is disabled.

  ## Parameters
  - `params`: A map containing CAPTCHA response parameters or nil.

  ## Returns
  - `true` if the CAPTCHA challenge is passed or disabled.
  - `false` if the CAPTCHA challenge fails or an error occurs during verification.
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

  defp do_recaptcha_passed?(recaptcha_secret_key, recaptcha_response) do
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
        body |> Jason.decode!() |> success?()

      false ->
        true

      _ ->
        false
    end
  end

  # v3 case
  defp success?(%{"success" => true, "score" => score, "hostname" => hostname}) do
    (!check_hostname?() || Helper.get_app_host() == hostname) &&
      check_recaptcha_v3_score(score)
  end

  # v2 case
  defp success?(%{"success" => true, "hostname" => hostname}) do
    !check_hostname?() || Helper.get_app_host() == hostname
  end

  defp success?(_resp), do: false

  defp check_recaptcha_v3_score(score) do
    if score >= 0.5 do
      true
    else
      false
    end
  end

  defp check_hostname? do
    Application.get_env(:block_scout_web, :recaptcha)[:check_hostname?]
  end
end
