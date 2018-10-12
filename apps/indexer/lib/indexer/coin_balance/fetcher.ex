defmodule Indexer.CoinBalance.Fetcher do
  @moduledoc """
  Fetches `t:Explorer.Chain.Address.CoinBalance.t/0` and updates `t:Explorer.Chain.Address.t/0` `fetched_coin_balance` and
  `fetched_coin_balance_block_number` to value at max `t:Explorer.Chain.Address.CoinBalance.t/0` `block_number` for the given `t:Explorer.Chain.Address.t/` `hash`.
  """

  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash}
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 500,
    max_concurrency: 4,
    init_chunk_size: 1000,
    task_supervisor: Indexer.CoinBalance.TaskSupervisor
  ]

  @doc """
  Asynchronously fetches balances for each address `hash` at the `block_number`.
  """
  @spec async_fetch_balances([
          %{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}
        ]) :: :ok
  def async_fetch_balances(balance_fields) when is_list(balance_fields) do
    entries = Enum.map(balance_fields, &entry/1)

    BufferedTask.buffer(__MODULE__, entries)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_options =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_options}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_unfetched_balances(initial, fn address_fields, acc ->
        address_fields
        |> entry()
        |> reducer.(acc)
      end)

    final
  end

  @impl BufferedTask
  def run(entries, _retries, json_rpc_named_arguments) do
    # the same address may be used more than once in the same block, but we only want one `Balance` for a given
    # `{address, block}`, so take unique params only
    unique_entries = Enum.uniq(entries)

    Logger.debug(fn -> "fetching #{length(unique_entries)} balances" end)

    unique_entries
    |> Enum.map(&entry_to_params/1)
    |> EthereumJSONRPC.fetch_balances(json_rpc_named_arguments)
    |> case do
      {:ok, balances_params} ->
        value_fetched_at = DateTime.utc_now()

        importable_balances_params = Enum.map(balances_params, &Map.put(&1, :value_fetched_at, value_fetched_at))

        addresses_params = balances_params_to_address_params(importable_balances_params)

        {:ok, _} =
          Chain.import(%{
            addresses: %{params: addresses_params, with: :balance_changeset},
            address_coin_balances: %{params: importable_balances_params}
          })

        :ok

      {:error, reason} ->
        Logger.debug(fn -> "failed to fetch #{length(unique_entries)} balances, #{inspect(reason)}" end)
        {:retry, unique_entries}
    end
  end

  defp entry_to_params(%{address_hash_bytes: address_hash_bytes, block_number: block_number})
       when is_integer(block_number) do
    {:ok, address_hash} = Hash.Address.cast(address_hash_bytes)
    %{block_quantity: integer_to_quantity(block_number), hash_data: to_string(address_hash)}
  end

  defp entry(%{address_hash: %Hash{bytes: address_hash_bytes}, block_number: block_number}) do
    %{address_hash_bytes: address_hash_bytes, block_number: block_number}
  end

  # We want to record all historical balances for an address, but have the address itself have balance from the
  # `Balance` with the greatest block_number for that address.
  def balances_params_to_address_params(balances_params) do
    balances_params
    |> Enum.group_by(fn %{address_hash: address_hash} -> address_hash end)
    |> Map.values()
    |> Stream.map(&Enum.max_by(&1, fn %{block_number: block_number} -> block_number end))
    |> Enum.map(fn %{address_hash: address_hash, block_number: block_number, value: value} ->
      %{hash: address_hash, fetched_coin_balance_block_number: block_number, fetched_coin_balance: value}
    end)
  end
end
