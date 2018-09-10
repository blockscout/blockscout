defmodule Indexer.Wobserver.BlockFetcher.Realtime do
  @moduledoc """
  Metrics and pages for `Indexer.BlockFetcher.Realtime`.
  """

  defstruct former_monotonic_milliseconds: nil,
            latest_monotonic_milliseconds: nil,
            latest_block_number: -1

  @table Indexer.Wobserver.Metrics

  def attach_to_telemetry do
    Telemetry.attach(__MODULE__, [:indexer, :block_fetcher, :realtime, :new_block], __MODULE__, :handle_event)
  end

  def handle_event([:indexer, :block_fetcher, :realtime, :new_block], number, _metadata, _config) do
    update(@table, number)
  end

  def page do
    %{duration: duration, elapsed: elapsed, latest_block_number: latest_block_number} = calculate(@table)

    %{
      "Realtime Block Fetcher" => %{
        "Time between last 2 blocks (ms)" => duration,
        "Time since last block (ms)" => elapsed,
        "Latest block number" => latest_block_number
      }
    }
  end

  def metrics do
    %{duration: duration, elapsed: elapsed, latest_block_number: latest_block_number} = calculate(@table)

    %{
      indexer_block_fetcher_realtime_last_block_number:
        {latest_block_number, :guage, "Realtime Block Fetcher latest block number"},
      indexer_block_fetcher_realtime_duration:
        {duration, :guage, "Realtime Block Fetcher duration between last 2 blocks (ms)"},
      indexer_block_fetcher_realtime_elapsed: {elapsed, :guage, "Realtime Block Fetcher time since last block (ms)"}
    }
  end

  def read(table) do
    case :ets.lookup(table, Indexer.BlockFetcher.Realtime) do
      [] -> %__MODULE__{}
      [{Indexer.BlockFetcher.Realtime, %__MODULE__{} = cached}] -> cached
    end
  end

  defp write(
         table,
         %__MODULE__{
           former_monotonic_milliseconds: former_monotonic_milliseconds,
           latest_monotonic_milliseconds: latest_monotonic_milliseconds,
           latest_block_number: latest_block_number
         } = data
       )
       when (former_monotonic_milliseconds == nil or is_integer(former_monotonic_milliseconds)) and
              is_integer(latest_monotonic_milliseconds) and is_integer(latest_block_number) do
    :ets.insert(table, {Indexer.BlockFetcher.Realtime, data})
  end

  def update(table, latest_block_number) when is_integer(latest_block_number) do
    former_monotonic_milliseconds = read(table)[:latest_monotonic_milliseconds]

    write(table, %__MODULE__{
      former_monotonic_milliseconds: former_monotonic_milliseconds,
      latest_monotonic_milliseconds: :erlang.monotonic_time(),
      latest_block_number: latest_block_number
    })
  end

  defp calculate(table) do
    %__MODULE__{
      former_monotonic_milliseconds: former_monotonic_milliseconds,
      latest_monotonic_milliseconds: latest_monotonic_milliseconds,
      latest_block_number: latest_block_number
    } = read(table)

    duration =
      if former_monotonic_milliseconds and latest_monotonic_milliseconds do
        latest_monotonic_milliseconds - former_monotonic_milliseconds
      else
        -1
      end

    elapsed =
      if latest_monotonic_milliseconds do
        :erlang.monotonic_time() - latest_monotonic_milliseconds
      else
        -1
      end

    %{duration: duration, elapsed: elapsed, latest_block_number: latest_block_number}
  end
end
