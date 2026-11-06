# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Token do
  @moduledoc """
  Fetches information about a token.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Hash.Address
  alias Explorer.Chain.Token
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Token.MetadataRetriever
  alias Indexer.{BufferedTask, Tracer}

  @behaviour BufferedTask

  @default_max_concurrency 10

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    if !state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      Chain.stream_uncataloged_token_contract_address_hashes(
        initial_acc,
        fn address, acc ->
          reducer.(address, acc)
        end,
        true
      )

    acc
  end

  @impl BufferedTask
  @decorate trace(name: "fetch", resource: "Indexer.Fetcher.Token.run/2", service: :indexer, tracer: Tracer)
  def run([token_contract_address], _json_rpc_named_arguments) do
    case Chain.token_from_address_hash(token_contract_address) do
      {:ok, %Token{} = token} ->
        catalog_token(token)
    end
  end

  @doc """
  Fetches token data asynchronously given a list of `t:Explorer.Chain.Token.t/0`s.
  """
  @spec async_fetch([Address.t()], boolean()) :: :ok
  def async_fetch(token_contract_addresses, realtime?) do
    BufferedTask.buffer(__MODULE__, token_contract_addresses, realtime?)
  end

  defp catalog_token(token) do
    token
    |> MetadataRetriever.get_functions_of(set_skip_metadata: true)
    |> case do
      %{skip_metadata: false} ->
        postpone_cataloging(token)

      token_params ->
        data_for_multichain = MultichainSearch.prepare_token_metadata_for_queue(token, token_params)

        %{}
        |> Map.put(token.contract_address_hash.bytes, data_for_multichain)
        |> MultichainSearch.send_token_info_to_queue(:metadata)

        {:ok, _} = Token.update(token, Map.put(token_params, :cataloged, true))
        :ok
    end
  end

  # Every getter failed for a reason that is not a contract failure (transport
  # error, rate limit, lagging node), so the token stays uncataloged. Left as
  # is, `init/3` would select it again right away: `Indexer.BufferedTask`
  # re-runs `init` without delay as long as the previous run pushed anything,
  # which turned 50 such tokens into ~80 failing `eth_call`/s on Unichain.
  # The next attempt is therefore pushed back exponentially, the way
  # `Indexer.Fetcher.TokenBalance.Helper` does for token balances.
  defp postpone_cataloging(token) do
    retries_count = (token.metadata_retries_count || 0) + 1
    refetch_after = define_refetch_after(retries_count)

    Logger.debug(fn ->
      "Cataloging of token #{to_string(token.contract_address_hash)} failed #{retries_count} time(s), " <>
        "next attempt after #{DateTime.to_iso8601(refetch_after)}"
    end)

    Token.schedule_metadata_refetch(token, retries_count, refetch_after)
  end

  defp define_refetch_after(retries_count) do
    config = Application.get_env(:indexer, __MODULE__)

    coef = config[:exp_timeout_coeff]
    max_refetch_interval = config[:max_refetch_interval]
    max_retries_count = :math.log(max_refetch_interval / 1000 / coef)

    value = floor(coef * :math.exp(min(retries_count, max_retries_count)))

    Timex.shift(Timex.now(), seconds: value)
  end

  defp defaults do
    [
      flush_interval: 300,
      max_batch_size: 1,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      task_supervisor: Indexer.Fetcher.Token.TaskSupervisor
    ]
  end
end
