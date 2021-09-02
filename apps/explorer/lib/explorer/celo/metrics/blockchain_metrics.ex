# credo:disable-for-this-file
defmodule Explorer.Celo.Metrics.BlockchainMetrics do
  @moduledoc "A context to collect blockchain metric functions"

  alias Ecto.Adapters.SQL
  alias Explorer.Repo

  def pending_blockcount do
    # todo: use ecto

    {:ok, %{rows: [[block_count]]}} =
      SQL.query(
        Repo,
        "select count(*) from pending_block_operations where fetch_internal_transactions = true"
      )

    block_count
  end
end
