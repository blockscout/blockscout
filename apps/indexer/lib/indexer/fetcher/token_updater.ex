defmodule Indexer.Fetcher.TokenUpdater do
  @moduledoc """
  Updates metadata for cataloged tokens
  """
  use Indexer.Fetcher

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Token.MetadataRetriever
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @max_batch_size 10
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Fetcher.TokenUpdater.TaskSupervisor,
    metadata: [fetcher: :token_updater]
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
  def init(initial, reducer, _) do
    metadata_updater_inverval = Application.get_env(:indexer, :metadata_updater_seconds_interval)
    interval_in_minutes = Kernel.round(metadata_updater_inverval / 60)

    {:ok, tokens} = Chain.stream_cataloged_token_contract_address_hashes(initial, reducer, interval_in_minutes)

    tokens
  end

  @impl BufferedTask
  def run(entries, _json_rpc_named_arguments) do
    Logger.debug("updating tokens")

    entries
    |> Enum.map(&to_string/1)
    |> MetadataRetriever.get_functions_of()
    |> case do
      {:ok, params} ->
        update_metadata(params)

      other ->
        Logger.error(fn -> ["failed to update tokens: ", inspect(other)] end,
          error_count: Enum.count(entries)
        )

        {:retry, entries}
    end
  end

  @doc false
  def update_metadata(metadata_list) when is_list(metadata_list) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    Enum.each(metadata_list, fn %{contract_address_hash: contract_address_hash} = metadata ->
      {:ok, hash} = Hash.Address.cast(contract_address_hash)

      with {:ok, %Token{cataloged: true} = token} <- Chain.token_from_address_hash(hash, options) do
        update_metadata(token, metadata)
      end
    end)
  end

  def update_metadata(%Token{} = token, metadata) do
    Chain.update_token(%{token | updated_at: DateTime.utc_now()}, metadata)
  end
end
