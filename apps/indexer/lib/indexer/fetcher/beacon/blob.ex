defmodule Indexer.Fetcher.Beacon.Blob do
  @moduledoc """
  Fills beacon_blobs DB table.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  alias Explorer.Repo
  alias Explorer.Chain.Beacon.{Blob, Reader}
  alias Explorer.Chain.Data
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.Beacon.Blob.Supervisor, as: BlobSupervisor
  alias Indexer.Fetcher.Beacon.Client

  @behaviour BufferedTask

  @default_max_batch_size 10
  @default_max_concurrency 1

  @doc """
  Asynchronously fetches blobs for given `block_timestamp`.
  """
  def async_fetch(block_timestamps) do
    if BlobSupervisor.disabled?() do
      :ok
    else
      BufferedTask.buffer(__MODULE__, block_timestamps |> Enum.map(&entry/1))
    end
  end

  @spec child_spec([...]) :: %{
          :id => any(),
          :start => {atom(), atom(), list()},
          optional(:modules) => :dynamic | [atom()],
          optional(:restart) => :permanent | :temporary | :transient,
          optional(:shutdown) => :brutal_kill | :infinity | non_neg_integer(),
          optional(:significant) => boolean(),
          optional(:type) => :supervisor | :worker
        }
  @doc false
  def child_spec([init_options, gen_server_options]) do
    state =
      :indexer
      |> Application.get_env(__MODULE__)
      |> Keyword.take([:start_block, :end_block, :reference_slot, :reference_timestamp, :slot_duration])
      |> Enum.into(%{})

    merged_init_options =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_options}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, state) do
    {:ok, final} =
      Reader.stream_missed_blob_transactions_timestamps(
        initial,
        fn fields, acc ->
          fields
          |> entry()
          |> reducer.(acc)
        end,
        state.start_block,
        state.end_block
      )

    final
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.Beacon.Blob.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(entries, state) do
    entry_count = Enum.count(entries)
    Logger.metadata(count: entry_count)

    Logger.debug(fn -> "fetching" end)

    entries
    |> Enum.map(&timestamp_to_slot(&1, state))
    |> Client.get_blob_sidecars()
    |> case do
      {:ok, fetched_blobs, retry_indices} ->
        run_fetched_blobs(fetched_blobs)

        if Enum.empty?(retry_indices) do
          :ok
        else
          {:retry, retry_indices |> Enum.map(&Enum.at(entries, &1))}
        end
    end
  end

  defp entry(block_timestamp) do
    DateTime.to_unix(block_timestamp)
  end

  defp timestamp_to_slot(block_timestamp, %{
         reference_timestamp: reference_timestamp,
         reference_slot: reference_slot,
         slot_duration: slot_duration
       }) do
    ((block_timestamp - reference_timestamp) |> div(slot_duration)) + reference_slot
  end

  defp run_fetched_blobs(fetched_blobs) do
    blobs =
      fetched_blobs
      |> Enum.flat_map(fn %{"data" => blobs} -> blobs end)
      |> Enum.map(&blob_entry/1)

    Repo.insert_all(Blob, blobs, on_conflict: :nothing, conflict_target: [:hash])
  end

  defp blob_entry(%{
         "blob" => blob,
         "kzg_commitment" => kzg_commitment,
         "kzg_proof" => kzg_proof
       }) do
    {:ok, kzg_commitment} = Data.cast(kzg_commitment)
    {:ok, blob} = Data.cast(blob)
    {:ok, kzg_proof} = Data.cast(kzg_proof)

    %{
      hash: Blob.hash(kzg_commitment.bytes),
      blob_data: blob,
      kzg_commitment: kzg_commitment,
      kzg_proof: kzg_proof
    }
  end

  defp defaults do
    [
      poll: false,
      flush_interval: :timer.seconds(3),
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      task_supervisor: Indexer.Fetcher.Beacon.Blob.TaskSupervisor,
      metadata: [fetcher: :beacon_blob]
    ]
  end
end
