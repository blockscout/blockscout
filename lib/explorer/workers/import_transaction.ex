defmodule Explorer.Workers.ImportTransaction do
  @moduledoc "Imports transaction by web3 conventions."

  alias Explorer.TransactionImporter

  @dialyzer {:nowarn_function, perform: 1}
  def perform(hash), do: TransactionImporter.import(hash)

  def perform_later(hash) do
    Exq.enqueue(Exq.Enqueuer, "transactions", __MODULE__, [hash])
  end
end
