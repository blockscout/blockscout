defmodule Explorer.Workers.ImportTransaction do
  @moduledoc """
    Manages the lifecycle of importing a single Transaction from web3.
  """

  alias Explorer.TransactionImporter
  alias Explorer.Workers.ImportReceipt

  @dialyzer {:nowarn_function, perform: 1}
  def perform(hash) when is_binary(hash) do
    TransactionImporter.import(hash)
    ImportReceipt.perform_later(hash)
  end

  @dialyzer {:nowarn_function, perform: 1}
  def perform(raw_transaction) when is_map(raw_transaction) do
    TransactionImporter.import(raw_transaction)
    ImportReceipt.perform_later(raw_transaction["hash"])
  end

  def perform_later(hash) do
    Exq.enqueue(Exq.Enqueuer, "transactions", __MODULE__, [hash])
  end
end
