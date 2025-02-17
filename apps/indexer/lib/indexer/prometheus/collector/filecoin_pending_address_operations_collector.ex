defmodule Indexer.Prometheus.Collector.FilecoinPendingAddressOperations do
  @moduledoc """
  Custom collector to count number of records in filecoin_pending_address_operations table.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :filecoin do
    use Prometheus.Collector

    # TODO: remove when https://github.com/elixir-lang/elixir/issues/13975 comes to elixir release
    alias Explorer.Chain.Filecoin.PendingAddressOperation, warn: false
    alias Explorer.Repo, warn: false
    alias Prometheus.Model, warn: false

    def collect_mf(_registry, callback) do
      query = PendingAddressOperation.fresh_operations_query()

      callback.(
        create_gauge(
          :filecoin_pending_address_operations,
          "Number of pending address operations that have not been fetched yet",
          Repo.aggregate(query, :count, timeout: :infinity)
        )
      )
    end

    def collect_metrics(:filecoin_pending_address_operations, count) do
      Model.gauge_metrics([{count}])
    end

    defp create_gauge(name, help, data) do
      Model.create_mf(name, help, :gauge, __MODULE__, data)
    end
  end
end
