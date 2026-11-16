# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Token do
  @moduledoc """
  Fetches information about a token.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Explorer.Chain
  alias Explorer.Chain.Hash.Address
  alias Explorer.Chain.Token
  alias Explorer.Chain.Token.Erc404
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
    if __MODULE__.Supervisor.disabled?() do
      :ok
    else
      BufferedTask.buffer(__MODULE__, token_contract_addresses, realtime?)
    end
  end

  defp catalog_token(token) do
    token
    |> MetadataRetriever.get_functions_of(set_skip_metadata: true)
    |> case do
      %{skip_metadata: false} ->
        :ok

      token_params ->
        data_for_multichain = MultichainSearch.prepare_token_metadata_for_queue(token, token_params)

        %{}
        |> Map.put(token.contract_address_hash.bytes, data_for_multichain)
        |> MultichainSearch.send_token_info_to_queue(:metadata)

        maybe_convert_to_erc404(token, token_params)
        {:ok, _} = Token.update(token, Map.put(token_params, :cataloged, true))
        :ok
    end
  end

  # The transfers imported before the token turned out to be an ERC-404 one were
  # parsed from its standard `Transfer` events with the ERC-721 and ERC-20 shapes.
  # The ones imported from now on get the ERC-404 shape, since the type stored
  # for the token takes precedence over the one derived from the logs.
  #
  # The conversion runs before the token is marked as cataloged. It retypes the
  # token first, so a failed attempt leaves an uncataloged ERC-404 token behind,
  # which is converted again on the next attempt to catalog it. Re-running the
  # conversion is safe, it only touches the rows which are not converted yet.
  # Tokens detected as ERC-404 from their dedicated events have nothing to
  # convert, see `Erc404.conversion_pending?/1`.
  defp maybe_convert_to_erc404(%Token{contract_address_hash: contract_address_hash}, %{type: "ERC-404"}) do
    Erc404.convert(contract_address_hash)
  end

  defp maybe_convert_to_erc404(
         %Token{type: "ERC-404", cataloged: cataloged, contract_address_hash: contract_address_hash},
         _token_params
       )
       when cataloged != true do
    if Erc404.conversion_pending?(contract_address_hash), do: Erc404.convert(contract_address_hash), else: :ok
  end

  defp maybe_convert_to_erc404(_token, _token_params), do: :ok

  defp defaults do
    [
      flush_interval: 300,
      max_batch_size: 1,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      task_supervisor: Indexer.Fetcher.Token.TaskSupervisor
    ]
  end
end
