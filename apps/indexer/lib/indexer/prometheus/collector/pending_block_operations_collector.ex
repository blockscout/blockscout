defmodule Indexer.Prometheus.Collector.PendingBlockOperations do
  @moduledoc """
  Custom collector to count number of records in pending_block_operations table.
  """

  use Prometheus.Collector

  alias Explorer.Chain.PendingBlockOperation
  alias Explorer.Repo
  alias Prometheus.Model

  def collect_mf(_registry, callback) do
    callback.(
      create_gauge(
        :pending_block_operations_count,
        "Number of records in pending_block_operations table",
        Repo.aggregate(PendingBlockOperation, :count)
      )
    )
  end

  def collect_metrics(:pending_block_operations_count, count) do
    Model.gauge_metrics([{count}])
  end

  defp create_gauge(name, help, data) do
    Model.create_mf(name, help, :gauge, __MODULE__, data)
  end
end
