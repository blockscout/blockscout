defmodule Explorer.Account.Notify do
  @moduledoc """
    Interface for notifier, for import and call from other modules
  """

  alias Explorer.Account
  alias Explorer.Account.Notifier.Notify

  require Logger

  def async(transactions) do
    Task.async(fn -> process(transactions) end)
  end

  defp process(transactions) do
    if Account.enabled?() do
      check_envs()
      Notify.call(transactions)
    end
  rescue
    err ->
      Logger.info("--- Notifier error", fetcher: :account)
      :error |> Exception.format(err, __STACKTRACE__) |> Logger.info(fetcher: :account)
  end

  defp check_envs do
    check_auth0()
    check_sendgrid()
  end

  defp check_auth0 do
    (Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)[:client_id] &&
       Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)[:client_secret] &&
       Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)[:domain]) ||
      raise "Auth0 not configured"
  end

  defp check_sendgrid do
    (Application.get_env(:explorer, Explorer.Account)[:sendgrid][:sender] &&
       Application.get_env(:explorer, Explorer.Account)[:sendgrid][:template]) ||
      raise "SendGrid not configured"
  end
end
