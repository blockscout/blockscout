defmodule Indexer.Token.Fetcher do
  @moduledoc """
  Fetches information about a token.
  """

  alias Explorer.Chain
  alias Explorer.Chain.Hash.Address
  alias Explorer.Chain.Token
  alias Explorer.Token.FunctionsReader
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @defaults [
    flush_interval: 300,
    max_batch_size: 1,
    max_concurrency: 10,
    task_supervisor: Indexer.Token.TaskSupervisor
  ]

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
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      Chain.stream_uncataloged_token_contract_address_hashes(initial_acc, fn address, acc ->
        reducer.(address, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run([token_contract_address], _json_rpc_named_arguments) do
    case Chain.token_from_address_hash(token_contract_address) do
      {:ok, %Token{cataloged: false} = token} ->
        catalog_token(token)

      {:ok, _} ->
        :ok
    end
  end

  @doc """
  Fetches token data asynchronously given a list of `t:Explorer.Chain.Token.t/0`s.
  """
  @spec async_fetch([Address.t()]) :: :ok
  def async_fetch(token_contract_addresses) do
    BufferedTask.buffer(__MODULE__, token_contract_addresses)
  end

  defp catalog_token(%Token{contract_address_hash: contract_address_hash} = token) do
    contract_functions = FunctionsReader.get_functions_of(contract_address_hash)

    token_params = Map.put(contract_functions, :cataloged, true)

    {:ok, _} = Chain.update_token(token, token_params)
    :ok
  end
end
