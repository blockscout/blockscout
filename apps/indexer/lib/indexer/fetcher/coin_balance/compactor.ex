# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.CoinBalance.Compactor do
  @moduledoc """
  Periodically deletes the coin balances that carry no balance change, following
  the chain head at a distance.

  A coin balance is written for every block an address is touched in, so a
  contract that is called in nearly every block gets a row per block although its
  balance almost never changes. Whether such a row is redundant cannot be told
  reliably when it is written: the blocks next to the chain head are imported
  concurrently and out of order, so a row of a lower block can still show up
  afterwards. This process therefore goes through the blocks that are at least
  `head_offset` blocks below the chain head, in batches of `batch_size` blocks,
  and leaves the decision on every row to
  `Explorer.Chain.Address.CoinBalance.delete_unchanged/3`.

  The number of the last processed block is kept in `last_fetched_counters`, so
  the process continues from it after a restart. The rows that could not be
  deleted when their block was processed, because the blocks below them were not
  settled yet, are left in place.
  """

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  require Logger

  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter

  @counter_type "coin_balances_compactor_last_block_number"

  @interval :timer.seconds(1)
  @batch_size 100
  @head_offset 1000

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments}
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(init_opts, gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  @impl GenServer
  def init(_opts) do
    Kernel.send(self(), :compact)

    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:compact, state) do
    compact_next_batch()

    Process.send_after(self(), :compact, interval())

    {:noreply, state}
  end

  @doc """
  Processes the next batch of blocks, if there are blocks far enough from the
  chain head that are not processed yet.

  ## Returns
  - `{:ok, {from_block_number, to_block_number, deleted_count}}` for a processed batch.
  - `:idle` when there is nothing to process yet.
  """
  @spec compact_next_batch() :: {:ok, {non_neg_integer(), non_neg_integer(), non_neg_integer()}} | :idle
  def compact_next_batch do
    from_block_number = last_block_number() + 1
    max_block_number = BlockNumber.get_max() - head_offset()

    if from_block_number <= max_block_number do
      to_block_number = min(from_block_number + batch_size() - 1, max_block_number)
      deleted_count = CoinBalance.delete_unchanged(from_block_number, to_block_number)

      {:ok, _} = LastFetchedCounter.upsert(%{counter_type: @counter_type, value: to_block_number})

      Logger.debug(
        "Deleted #{deleted_count} unchanged coin balances in blocks #{from_block_number}..#{to_block_number}"
      )

      {:ok, {from_block_number, to_block_number, deleted_count}}
    else
      :idle
    end
  end

  # The block number the previous batch ended at, or -1 when nothing is processed yet.
  defp last_block_number do
    case LastFetchedCounter.get(@counter_type, nullable: true) do
      nil -> -1
      value -> Decimal.to_integer(value)
    end
  end

  defp batch_size do
    Application.get_env(:indexer, __MODULE__)[:batch_size] || @batch_size
  end

  defp interval do
    Application.get_env(:indexer, __MODULE__)[:interval] || @interval
  end

  defp head_offset do
    Application.get_env(:indexer, __MODULE__)[:head_offset] || @head_offset
  end
end
