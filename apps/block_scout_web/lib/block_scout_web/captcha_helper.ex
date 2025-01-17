defmodule BlockScoutWeb.CaptchaHelper do
  @moduledoc """
  A helper for CAPTCHA
  """
  require Logger

  alias Explorer.Helper

  @doc """
    Verifies if the CAPTCHA challenge has been passed based on the provided parameters.

    This function first checks for a bypass token, then handles both reCAPTCHA v3 and v2
    responses, as well as cases where CAPTCHA is disabled.

    ## Parameters
    - `params`: A map containing CAPTCHA response parameters or nil. Can include:
      * `"recaptcha_bypass_token"` - A token to bypass CAPTCHA verification
      * `"recaptcha_v3_response"` - A reCAPTCHA v3 response token
      * `"recaptcha_response"` - A reCAPTCHA v2 response token

    ## Returns
    - `true` if the CAPTCHA challenge is passed or disabled, or if a valid bypass token is provided.
    - `false` if the CAPTCHA challenge fails or an error occurs during verification.
  """
  @spec recaptcha_passed?(%{String.t() => String.t()} | nil) :: bool
  def recaptcha_passed?(%{"recaptcha_bypass_token" => given_bypass_token}) do
    bypass_token = Application.get_env(:block_scout_web, :recaptcha)[:bypass_token]

    if bypass_token != "" && given_bypass_token == bypass_token do
      Logger.warning("reCAPTCHA bypass token used")
      true
    else
      false
    end
  end

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

      error ->
        Logger.error("Failed to verify reCAPTCHA: #{inspect(error)}")
        false
    end
  end

  # v3 case
  defp success?(%{"success" => true, "score" => score, "hostname" => hostname}) do
    unless Helper.get_app_host() == hostname do
      Logger.warning("reCAPTCHA v3 Hostname mismatch: #{inspect(hostname)} != #{inspect(Helper.get_app_host())}")
    end

    if Helper.get_app_host() == hostname and not check_recaptcha_v3_score(score) do
      Logger.warning("reCAPTCHA v3 low score: #{inspect(score)} < #{inspect(score_threshold())}")
    end

    (!check_hostname?() || Helper.get_app_host() == hostname) &&
      check_recaptcha_v3_score(score)
  end

  # v2 case
  defp success?(%{"success" => true, "hostname" => hostname}) do
    unless Helper.get_app_host() == hostname do
      Logger.warning("reCAPTCHA v2 Hostname mismatch: #{inspect(hostname)} != #{inspect(Helper.get_app_host())}")
    end

    !check_hostname?() || Helper.get_app_host() == hostname
  end

  defp success?(resp) do
    Logger.error("Failed to verify reCAPTCHA, unexpected response: #{inspect(resp)}")
    false
  end

  defp check_recaptcha_v3_score(score) do
    if score >= score_threshold() do
      true
    else
      false
    end
  end

  defp check_hostname? do
    Application.get_env(:block_scout_web, :recaptcha)[:check_hostname?]
  end

  defp score_threshold do
    Application.get_env(:block_scout_web, :recaptcha)[:score_threshold]
  end
end
