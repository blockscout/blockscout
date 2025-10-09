defmodule Indexer.Block.Catchup.MassiveBlocksFetcher do
  @moduledoc """
  Fetches and indexes blocks by numbers from massive_blocks table.
  """

  use GenServer

  require Logger

  alias Explorer.Utility.MassiveBlock
  alias Indexer.Block.Fetcher

  @increased_interval 10000

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    send_new_task()

    {:ok, %{block_fetcher: generate_block_fetcher(), low_priority_blocks: []}}
  end

  @impl true
  def handle_info(:task, %{low_priority_blocks: low_priority_blocks} = state) do
    {result, new_low_priority_blocks} =
      case MassiveBlock.get_last_block_number(low_priority_blocks) do
        nil ->
          case low_priority_blocks do
            [number | rest] ->
              failed_blocks = process_block(state.block_fetcher, number)
              {:processed, rest ++ failed_blocks}

            [] ->
              {:empty, []}
          end

        number ->
          failed_blocks = process_block(state.block_fetcher, number)
          {:processed, low_priority_blocks ++ failed_blocks}
      end

    case result do
      :processed -> send_new_task()
      :empty -> send_new_task(@increased_interval)
    end

    {:noreply, %{state | low_priority_blocks: new_low_priority_blocks}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp process_block(block_fetcher, number) do
    case Fetcher.fetch_and_import_range(block_fetcher, number..number, %{timeout: :infinity}) do
      {:ok, _result} ->
        Logger.info("MassiveBlockFetcher successfully processed block #{inspect(number)}")
        MassiveBlock.delete_block_number(number)
        []

      {:error, error} ->
        Logger.error("MassiveBlockFetcher failed: #{inspect(error)}")
        [number]
    end
  rescue
    error ->
      Logger.error("MassiveBlockFetcher failed: #{inspect(error)}")
      [number]
  end

  defp generate_block_fetcher do
    receipts_batch_size = Application.get_env(:indexer, :receipts_batch_size)
    receipts_concurrency = Application.get_env(:indexer, :receipts_concurrency)
    json_rpc_named_arguments = Application.get_env(:indexer, :json_rpc_named_arguments)

    %Fetcher{
      broadcast: :catchup,
      callback_module: Indexer.Block.Catchup.Fetcher,
      json_rpc_named_arguments: json_rpc_named_arguments,
      receipts_batch_size: receipts_batch_size,
      receipts_concurrency: receipts_concurrency
    }
  end

  defp send_new_task(interval \\ 0) do
    Process.send_after(self(), :task, interval)
  end
end
