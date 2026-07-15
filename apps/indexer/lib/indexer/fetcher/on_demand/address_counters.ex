# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.OnDemand.AddressCounters do
  @moduledoc """
  Updates address counter caches on-demand.
  """

  use Indexer.Fetcher, restart: :permanent

  alias Explorer.Chain.Address

  alias Explorer.Chain.Cache.Counters.{
    AddressTokenTransfersCount,
    AddressTransactionsCount,
    AddressTransactionsGasUsageSum
  }

  alias Explorer.Utility.RateLimiter
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @default_max_batch_size 100
  @default_max_concurrency 2

  @spec trigger_fetch(String.t() | nil, Address.t()) :: :ok
  def trigger_fetch(caller \\ nil, address) do
    if __MODULE__.Supervisor.disabled?() or RateLimiter.check_rate(caller, :on_demand) == :deny do
      :ok
    else
      BufferedTask.buffer(__MODULE__, [address], false)
    end
  end

  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, %{})

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(_, _, _) do
    {0, []}
  end

  @impl BufferedTask
  def run(addresses, _state) do
    Enum.each(addresses, fn address ->
      AddressTransactionsCount.fetch(address)
      AddressTokenTransfersCount.fetch(address)
      AddressTransactionsGasUsageSum.fetch(address)
    end)
  end

  defp defaults do
    [
      poll: false,
      flush_interval: :timer.seconds(3),
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :address_counters_on_demand]
    ]
  end
end
