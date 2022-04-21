defmodule Explorer.Accounts.Notify do
  @moduledoc """
    Interface for notifier, for import and call from other modules
  """

  alias Explorer.Accounts.Notifier.Notify

  require Logger

  def async(transactions) do
    Task.async(fn -> process(transactions) end)
  end

  defp process(transactions) do
    Notify.call(transactions)
  rescue
    err ->
      Logger.info("--- Notifier error", fetcher: :account)
      Logger.info(err, fetcher: :account)
  end
end
