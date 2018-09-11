defmodule Indexer.TokenBalance.Fetcher do
  @moduledoc """
  Fetches the token balances values.
  """

  alias Indexer.{BufferedTask, TokenBalances}
  alias Explorer.Chain
  alias Explorer.Chain.{Hash, Address.TokenBalance}

  @behaviour BufferedTask

  @defaults [
    flush_interval: 300,
    max_batch_size: 1,
    max_concurrency: 10,
    init_chunk_size: 1,
    task_supervisor: Indexer.TokenBalance.TaskSupervisor
  ]

  def async_fetch(token_balances_params) do
    BufferedTask.buffer(__MODULE__, token_balances_params)
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
      Chain.stream_unfetched_token_balances(initial, fn token_balances_params, acc ->
        reducer.(token_balances_params, acc)
      end)

    final
  end

  @impl BufferedTask
  def run(token_balances, _retries, _json_rpc_named_arguments) do
    {:ok, token_balances_params} =
      token_balances
      |> Stream.map(&format_params/1)
      |> TokenBalances.fetch_token_balances_from_blockchain()

    {:ok, %{token_balances: [_]}} = Chain.import(%{token_balances: %{params: token_balances_params}})

    :ok
  end

  defp format_params(%TokenBalance{
         token_contract_address_hash: token_contract_address_hash,
         address_hash: address_hash,
         block_number: block_number
       }) do
    %{
      token_contract_address_hash: Hash.to_string(token_contract_address_hash),
      address_hash: Hash.to_string(address_hash),
      block_number: block_number
    }
  end
end
