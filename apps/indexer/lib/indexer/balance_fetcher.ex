defmodule Indexer.BalanceFetcher do
  @moduledoc """
  Fetches `t:Explorer.Chain.Balance.t/0` and updates `t:Explorer.Chain.Address.t/0` `fetched_balance` and
  `fetched_balance_block_number` to value at max `t:Explorer.Chain.Balance.t/0` `block_number` for the given `t:Explorer.Chain.Address.t/` `hash`.
  """

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
    task_supervisor: Indexer.TaskSupervisor
  ]

  @doc """
  Asynchronously fetches balances for each address `hash` at the `block_number`.
  """
  @spec async_fetch_balances([
          %{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}
        ]) :: :ok
  def async_fetch_balances(balance_fields) when is_list(balance_fields) do
    params_list = Enum.map(balance_fields, &balance_fields_to_params/1)

    BufferedTask.buffer(__MODULE__, params_list)
  end

  @doc false
  def child_spec(provided_opts) do
    {state, mergable_opts} = Keyword.pop(provided_opts, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    opts =
      @defaults
      |> Keyword.merge(mergable_opts)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, {__MODULE__, opts}}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_unfetched_balances(initial, fn address_fields, acc ->
        address_fields
        |> balance_fields_to_params()
        |> reducer.(acc)
      end)

    final
  end

  @impl BufferedTask
  def run(params_list, _retries, json_rpc_named_arguments) do
    # the same address may be used more than once in the same block, but we only want one `Balance` for a given
    # `{address, block}`, so take unique params only
    unique_params_list = Enum.uniq(params_list)

    Indexer.debug(fn -> "fetching #{length(unique_params_list)} balances" end)

    case EthereumJSONRPC.fetch_balances(unique_params_list, json_rpc_named_arguments) do
      {:ok, balances_params} ->
        addresses_params = balances_params_to_address_params(balances_params)

        {:ok, _} =
          Chain.import(%{
            addresses: %{params: addresses_params, with: :balance_changeset},
            balances: %{params: balances_params}
          })

        :ok

      {:error, reason} ->
        Indexer.debug(fn -> "failed to fetch #{length(unique_params_list)} balances, #{inspect(reason)}" end)
        {:retry, unique_params_list}
    end
  end

  defp balance_fields_to_params(%{address_hash: address_hash, block_number: block_number})
       when is_integer(block_number) do
    %{block_quantity: integer_to_quantity(block_number), hash_data: to_string(address_hash)}
  end

  # We want to record all historical balances for an address, but have the address itself have balance from the
  # `Balance` with the greatest block_number for that address.
  defp balances_params_to_address_params(balances_params) do
    balances_params
    |> Enum.group_by(fn %{address_hash: address_hash} -> address_hash end)
    |> Map.values()
    |> Stream.map(&Enum.max_by(&1, fn %{block_number: block_number} -> block_number end))
    |> Enum.map(fn %{address_hash: addresss_hash, block_number: block_number, value: value} ->
      %{hash: addresss_hash, fetched_balance_block_number: block_number, fetched_balance: value}
    end)
  end
end
