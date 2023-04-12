defmodule Indexer.Fetcher.Sanitize.TokenInstance do
  @moduledoc """
  Fetches information about a token instance.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  alias Explorer.Chain
  alias Explorer.Token.InstanceMetadataRetriever
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @default_max_batch_size 1
  @default_max_concurrency 10

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
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
      Chain.stream_token_instances_with_error(initial_acc, fn data, acc ->
        reducer.(data, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run([%{contract_address_hash: hash, token_id: token_id}], _json_rpc_named_arguments) do
    fetch_instance(hash, token_id)

    :ok
  end

  defp fetch_instance(token_contract_address_hash, token_id) do
    case InstanceMetadataRetriever.fetch_metadata(to_string(token_contract_address_hash), Decimal.to_integer(token_id)) do
      {:ok, %{metadata: metadata}} ->
        params = %{
          token_id: token_id,
          token_contract_address_hash: token_contract_address_hash,
          metadata: metadata,
          error: nil
        }

        {:ok, _result} = Chain.upsert_token_instance(params)

      {:ok, %{error: error}} ->
        params = %{
          token_id: token_id,
          token_contract_address_hash: token_contract_address_hash,
          error: error
        }

        {:ok, _result} = Chain.upsert_token_instance(params)

      result ->
        Logger.debug(
          [
            "failed to fetch token instance metadata for #{inspect({to_string(token_contract_address_hash), Decimal.to_integer(token_id)})}: ",
            inspect(result)
          ],
          fetcher: :token_instances
        )

        :ok
    end
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(3),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      poll: true,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
