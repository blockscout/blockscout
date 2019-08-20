defmodule Indexer.Block.Reindex.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges refetching all the data even if blocks were already fectched
  """

  require Logger

  import Indexer.Block.Fetcher,
    only: [
      async_import_block_rewards: 1,
      async_import_coin_balances: 2,
      async_import_created_contract_codes: 1,
      async_import_internal_transactions: 2,
      async_import_replaced_transactions: 1,
      async_import_tokens: 1,
      async_import_token_balances: 1,
      async_import_uncles: 1,
      fetch_and_import_range: 2
    ]

  alias Ecto.Changeset
  alias Explorer.Chain
  alias Indexer.{Block, Tracer}
  alias Indexer.Block.Catchup.Sequence
  alias Indexer.Memory.Shrinkable

  @behaviour Block.Fetcher

  # These are all the *default* values for options.
  # DO NOT use them directly in the code.  Get options from `state`.

  @blocks_batch_size 10
  @blocks_concurrency 10
  @sequence_name :block_reindex_sequencer

  defstruct blocks_batch_size: @blocks_batch_size,
            blocks_concurrency: @blocks_concurrency,
            block_fetcher: nil,
            memory_monitor: nil

  def task(
        %__MODULE__{
          blocks_batch_size: blocks_batch_size,
          block_fetcher: %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments}
        } = state
      ) do
    Logger.metadata(fetcher: :block_reindex)

    case reindex_range() do
      {:error, :no_range} -> Logger.warn(fn -> "Reindex blocks are not set" end)
      {:ok, range} -> reindex(range, state)
    end
  end

  defp reindex(
         start_block..end_block = range,
         %__MODULE__{blocks_batch_size: blocks_batch_size} = state
       ) do
    Logger.metadata(first_block_number: start_block, last_block_number: end_block)

    set_refetch_needed_flag(range)

    sequence_opts = put_memory_monitor([ranges: [range], step: -1 * blocks_batch_size], state)
    gen_server_opts = [name: @sequence_name]
    {:ok, sequence} = Sequence.start_link(sequence_opts, gen_server_opts)
    Sequence.cap(sequence)

    # stream_fetch_and_import(state, sequence)

    Shrinkable.shrunk?(sequence)
  end

  def reindex_range do
    start_block = Application.get_env(:explorer, Indexer.Block.Reindex.Fetcher)[:start_block]
    end_block = Application.get_env(:explorer, Indexer.Block.Reindex.Fetcher)[:end_block]

    case start_block..end_block do
      0..0 ->
        {:error, :no_range}

      range ->
        {:ok, range}
    end
  end

  defp set_refetch_needed_flag(start_block..end_block) do
    Chain.set_refetch_needed_flag(start_block, end_block)
  end

  defp put_memory_monitor(sequence_options, %__MODULE__{memory_monitor: nil}) when is_list(sequence_options),
    do: sequence_options

  defp put_memory_monitor(sequence_options, %__MODULE__{memory_monitor: memory_monitor})
       when is_list(sequence_options) do
    Keyword.put(sequence_options, :memory_monitor, memory_monitor)
  end

  defp stream_fetch_and_import(%__MODULE__{blocks_concurrency: blocks_concurrency} = state, sequence)
       when is_pid(sequence) do
    sequence
    |> Sequence.build_stream()
    # |> Task.async_stream(
    #   &fetch_and_import_range_from_sequence(state, &1, sequence),
    #   max_concurrency: blocks_concurrency,
    #   timeout: :infinity
    # )
    |> Stream.run()
  end
end
