defmodule Explorer.Workers.ImportReceipt do
  @moduledoc "Imports transaction by web3 conventions."

  alias Explorer.ReceiptImporter

  @dialyzer {:nowarn_function, perform: 1}
  def perform(hash), do: ReceiptImporter.import(hash)

  def perform_later(hash) do
    Exq.enqueue(Exq.Enqueuer, "receipts", __MODULE__, [hash])
  end
end
