defmodule Indexer.TokenBalance.Fetcher do
  @moduledoc """
  Fetches the token balances values.
  """

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Indexer.{BufferedTask, TokenBalances}

  @behaviour BufferedTask

  @defaults [
    flush_interval: 300,
    max_batch_size: 100,
    max_concurrency: 10,
    task_supervisor: Indexer.TokenBalance.TaskSupervisor
  ]

  @max_retries 3

  @spec async_fetch([]) :: :ok
  def async_fetch(token_balances) do
    formatted_params = Enum.map(token_balances, &entry/1)
    BufferedTask.buffer(__MODULE__, formatted_params, :infinity)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_unfetched_token_balances(initial, fn token_balance, acc ->
        token_balance
        |> entry()
        |> reducer.(acc)
      end)

    final
  end

  @impl BufferedTask
  def run(entries, _json_rpc_named_arguments) do
    result =
      entries
      |> Enum.map(&format_params/1)
      |> Enum.map(&Map.put(&1, :retries_count, &1.retries_count + 1))
      |> fetch_from_blockchain()
      |> import_token_balances()

    if result == :ok do
      :ok
    else
      {:retry, entries}
    end
  end

  def fetch_from_blockchain(params_list) do
    {:ok, token_balances} =
      params_list
      |> Enum.filter(&(&1.retries_count <= @max_retries))
      |> TokenBalances.fetch_token_balances_from_blockchain()

    token_balances
  end

  def import_token_balances(token_balances_params) do
    addresses_params = format_and_filter_address_params(token_balances_params)

    import_params = %{
      addresses: %{params: addresses_params},
      address_token_balances: %{params: token_balances_params},
      address_current_token_balances: %{params: token_balances_params},
      timeout: :infinity
    }

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.debug(fn -> "failed to import #{length(token_balances_params)} token balances, #{inspect(reason)}" end)

        :error
    end
  end

  defp format_and_filter_address_params(token_balances_params) do
    token_balances_params
    |> Enum.map(&%{hash: &1.address_hash})
    |> Enum.uniq()
  end

  defp entry(
         %{
           token_contract_address_hash: token_contract_address_hash,
           address_hash: address_hash,
           block_number: block_number
         } = token_balance
       ) do
    retries_count = Map.get(token_balance, :retries_count, 0)

    {address_hash.bytes, token_contract_address_hash.bytes, block_number, retries_count}
  end

  defp format_params({address_hash_bytes, token_contract_address_hash_bytes, block_number, retries_count}) do
    {:ok, token_contract_address_hash} = Hash.Address.cast(token_contract_address_hash_bytes)
    {:ok, address_hash} = Hash.Address.cast(address_hash_bytes)

    %{
      token_contract_address_hash: to_string(token_contract_address_hash),
      address_hash: to_string(address_hash),
      block_number: block_number,
      retries_count: retries_count
    }
  end
end
