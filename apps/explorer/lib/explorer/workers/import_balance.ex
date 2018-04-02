defmodule Explorer.Workers.ImportBalance do
  @moduledoc "A worker that imports the balance for a given address."

  alias Explorer.BalanceImporter

  def perform(hash) do
    BalanceImporter.import(hash)
  end

  def perform_later(hash) do
    Exq.enqueue(Exq.Enqueuer, "balances", __MODULE__, [hash])
  end
end
