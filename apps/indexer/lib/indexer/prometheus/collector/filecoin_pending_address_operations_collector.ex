defmodule Indexer.Prometheus.Collector.FilecoinPendingAddressOperations do
  @moduledoc """
  Custom collector to count number of records in filecoin_pending_address_operations table.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :filecoin do
    use Prometheus.Collector

    alias Explorer.Chain.Filecoin.PendingAddressOperation
    alias Explorer.Repo
    alias Prometheus.Model

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
