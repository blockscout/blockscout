defmodule Explorer.Account.Notify do
  @moduledoc """
    Interface for notifier, for import and call from other modules
  """

  alias Explorer.Account
  alias Explorer.Account.Notifier.Notify
  alias Explorer.ThirdPartyIntegrations.{Auth0, Dynamic, Keycloak}

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
    check_authentication_provider()
    check_sendgrid()
  end

  defp check_authentication_provider do
    Auth0.enabled?() || Keycloak.enabled?() || Dynamic.enabled?() ||
      raise "No authentication provider configured"
  end

  defp check_sendgrid do
    (Application.get_env(:explorer, Explorer.Account)[:sendgrid][:sender] &&
       Application.get_env(:explorer, Explorer.Account)[:sendgrid][:template]) ||
      raise "SendGrid not configured"
  end
end
