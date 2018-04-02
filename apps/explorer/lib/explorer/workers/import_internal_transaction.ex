defmodule Explorer.Workers.ImportInternalTransaction do
  @moduledoc "Imports internal transactions via Parity trace endpoints."

  alias Explorer.InternalTransactionImporter

  @dialyzer {:nowarn_function, perform: 1}
  def perform(hash), do: InternalTransactionImporter.import(hash)

  def perform_later(hash) do
    Exq.enqueue(Exq.Enqueuer, "internal_transactions", __MODULE__, [hash])
  end
end
