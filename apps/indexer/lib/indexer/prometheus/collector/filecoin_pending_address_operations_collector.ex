defmodule Indexer.Prometheus.Collector.FilecoinPendingAddressOperations do
  @moduledoc """
  Custom collector to count number of records in filecoin_pending_address_operations table.
  """

  use Prometheus.Collector

  alias Explorer.Chain.Filecoin.PendingAddressOperation
  alias Explorer.Repo
  alias Prometheus.Model

  def collect_mf(_registry, callback) do
    callback.(
      create_gauge(
        :filecoin_pending_address_operations,
        "Number of records in filecoin_pending_address_operations table",
        Repo.aggregate(PendingAddressOperation, :count, timeout: :infinity)
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
