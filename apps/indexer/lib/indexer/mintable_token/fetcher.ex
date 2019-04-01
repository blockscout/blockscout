defmodule Indexer.MintableToken.Fetcher do
  @moduledoc """
  Refreshes total supply of mintable tokens.
  """

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Explorer.Token.MetadataRetriever
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @refresh_period_in_day 7

  @defaults [
    flush_interval: 300,
    max_batch_size: 1,
    max_concurrency: 10,
    task_supervisor: Indexer.MintableToken.TaskSupervisor
  ]

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
    today = DateTime.utc_now()
    last_update = Timex.shift(today, days: -@refresh_period_in_day)

    {:ok, acc} =
      Chain.stream_mintable_token_contract_address_hashes(initial_acc, last_update, fn address, acc ->
        reducer.(address, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run([token_contract_address], _json_rpc_named_arguments) do
    today = DateTime.utc_now()
    last_update = Timex.shift(today, days: -@refresh_period_in_day)

    {:ok, %Token{updated_at: updated_at} = token} = Chain.token_from_address_hash(token_contract_address)

    if DateTime.diff(last_update, updated_at) <= 0 do
      refresh_token(token)
    else
      :ok
    end
  end

  defp refresh_token(%Token{contract_address_hash: contract_address_hash} = token) do
    token_params =
      contract_address_hash
      |> MetadataRetriever.get_functions_of()
      |> Map.put(:cataloged, true)

    {:ok, _} = Chain.update_token(token, token_params)
    :ok
  end
end
