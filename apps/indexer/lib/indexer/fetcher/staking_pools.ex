defmodule Indexer.Fetcher.StakingPools do
  @moduledoc """
  Fetches staking pools and send to be imported in `Address.Name` table
  """

  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Explorer.Chain
  alias Explorer.Staking.PoolsReader
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @defaults [
    flush_interval: 300,
    max_batch_size: 100,
    max_concurrency: 10,
    task_supervisor: Indexer.Fetcher.StakingPools.TaskSupervisor
  ]

  @max_retries 3

  @spec async_fetch() :: :ok
  def async_fetch do
    pid = GenServer.whereis(__MODULE__)

    if pid && Process.alive?(pid) do
      pools =
        PoolsReader.get_pools()
        |> Enum.map(&entry/1)

      BufferedTask.buffer(__MODULE__, pools, :infinity)
    end
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      @defaults
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, {0, []})

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(_initial, reducer, acc) do
    PoolsReader.get_pools()
    |> Enum.map(&entry/1)
    |> Enum.reduce(acc, &reducer.(&1, &2))
  end

  @impl BufferedTask
  def run(pools, _json_rpc_named_arguments) do
    failed_list =
      pools
      |> Enum.map(&Map.put(&1, :retries_count, &1.retries_count + 1))
      |> fetch_from_blockchain()
      |> import_pools()

    if failed_list == [] do
      :ok
    else
      {:retry, failed_list}
    end
  end

  def entry(pool_address) do
    %{
      staking_address: pool_address,
      retries_count: 0
    }
  end

  defp fetch_from_blockchain(addresses) do
    addresses
    |> Enum.filter(&(&1.retries_count <= @max_retries))
    |> Enum.map(fn %{staking_address: staking_address} = pool ->
      case PoolsReader.pool_data(staking_address) do
        {:ok, data} ->
          Map.merge(pool, data)

        error ->
          Map.put(pool, :error, error)
      end
    end)
  end

  defp import_pools(pools) do
    {failed, success} =
      Enum.reduce(pools, {[], []}, fn
        %{error: _error, staking_address: address}, {failed, success} ->
          {[address | failed], success}

        pool, {failed, success} ->
          {failed, [changeset(pool) | success]}
      end)

    import_params = %{
      staking_pools: %{params: success},
      timeout: :infinity
    }

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.debug(fn -> ["failed to import staking pools: ", inspect(reason)] end,
          error_count: Enum.count(pools)
        )
    end

    failed
  end

  defp changeset(%{staking_address: staking_address} = pool) do
    {:ok, mining_address} = Chain.Hash.Address.cast(pool[:mining_address])

    data =
      pool
      |> Map.delete(:staking_address)
      |> Map.put(:mining_address, mining_address)

    %{
      name: "anonymous",
      primary: true,
      address_hash: staking_address,
      metadata: data
    }
  end
end
