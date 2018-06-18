defmodule Explorer.Indexer.AddressBalanceFetcher do
  @moduledoc """
  Fetches `t:Explorer.Chain.Address.t/0` `fetched_balance`.
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias Explorer.{BufferedTask, Chain}
  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Indexer

  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 500,
    max_concurrency: 4,
    init_chunk_size: 1000,
    task_supervisor: Explorer.Indexer.TaskSupervisor
  ]

  @doc """
  Asynchronously fetches balances for each address `hash` at the `block_number`.
  """
  @spec async_fetch_balances([%{required(:block_number) => Block.block_number(), required(:hash) => Hash.Truncated.t()}]) ::
          :ok
  def async_fetch_balances(address_fields) when is_list(address_fields) do
    params_list = Enum.map(address_fields, &address_fields_to_params/1)

    BufferedTask.buffer(__MODULE__, params_list)
  end

  @doc false
  def child_spec(provided_opts) do
    opts = Keyword.merge(@defaults, provided_opts)
    Supervisor.child_spec({BufferedTask, {__MODULE__, opts}}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer) do
    {:ok, final} =
      Chain.stream_unfetched_addresses(initial, fn address_fields, acc ->
        address_fields
        |> address_fields_to_params()
        |> reducer.(acc)
      end)

    final
  end

  @impl BufferedTask
  def run(params_list, _retries) do
    Indexer.debug(fn -> "fetching #{length(params_list)} balances" end)

    case EthereumJSONRPC.fetch_balances(params_list) do
      {:ok, addresses_params} ->
        {:ok, _} = Chain.update_balances(addresses_params)
        :ok

      {:error, reason} ->
        Indexer.debug(fn -> "failed to fetch #{length(params_list)} balances, #{inspect(reason)}" end)
        :retry
    end
  end

  defp address_fields_to_params(%{block_number: block_number, hash: hash}) when is_integer(block_number) do
    %{block_quantity: integer_to_quantity(block_number), hash_data: to_string(hash)}
  end
end
