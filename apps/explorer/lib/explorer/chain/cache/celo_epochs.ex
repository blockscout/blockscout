defmodule Explorer.Chain.Cache.CeloEpochs do
  @moduledoc """
  Cache for efficiently mapping block numbers to epoch numbers in Celo blockchain.

  This implementation uses:
  1. A direct mathematical calculation for pre-migration epochs
  2. An ordered cache of post-migration epochs for efficient lookups
  """

  use Explorer.Chain.OrderedCache,
    name: :celo_epochs_cache,
    ttl_check_interval: :timer.minutes(1),
    global_ttl: :timer.minutes(5),
    # Adjust based on expected number of post-migration epochs
    max_size: 256

  @type element :: %{
          number: non_neg_integer(),
          start_block_number: non_neg_integer(),
          end_block_number: non_neg_integer() | nil
        }

  @type id :: non_neg_integer()

  import Ecto.Query, only: [select: 3]

  alias Explorer.Chain
  alias Explorer.Chain.Block
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Celo.{Epoch, Helper}

  @impl Explorer.Chain.OrderedCache
  def element_to_id(epoch) when is_map(epoch), do: epoch.number

  @doc """
  Gets the epoch number for a given block number. Uses mathematical formula for
  pre-migration blocks and cached data for post-migration blocks.
  """
  def block_number_to_epoch_number(block_number) do
    block_number
    |> Helper.pre_migration_block_number?()
    |> if do
      # For pre-migration blocks, use the mathematical formula
      Helper.block_number_to_epoch_number(block_number)
    else
      # For post-migration blocks, use the ordered cache
      fetch_post_migration_epoch_number(block_number)
    end
  end

  @doc """
  Retrieves the epoch number of the last fetched block.
  """
  @spec last_block_epoch_number() :: Block.block_number()
  def last_block_epoch_number do
    BlockNumber.get_max() |> block_number_to_epoch_number()
  end

  @spec fetch_post_migration_epoch_number(non_neg_integer()) :: non_neg_integer() | nil
  defp fetch_post_migration_epoch_number(block_number) do
    with {:cache, nil} <- {:cache, fetch_epoch_from_cache(block_number)},
         {:db, nil} <- {:db, fetch_epoch_from_db(block_number)} do
      nil
    else
      {source, epoch} ->
        # If the epoch is found in the database, update the cache
        if source == :db do
          update(epoch)
        end

        epoch.number
    end
  end

  @spec fetch_epoch_from_cache(non_neg_integer()) :: element() | nil
  defp fetch_epoch_from_cache(block_number) do
    Enum.find(all(), fn
      %{end_block_number: nil} = epoch ->
        epoch.start_block_number <= block_number

      epoch ->
        epoch.start_block_number <= block_number and
          block_number <= epoch.end_block_number
    end)
  end

  @spec fetch_epoch_from_db(non_neg_integer()) :: element() | nil
  defp fetch_epoch_from_db(block_number) do
    block_number
    |> Epoch.block_number_to_epoch_query()
    |> select([e], %{
      number: e.number,
      start_block_number: e.start_block_number,
      end_block_number: e.end_block_number
    })
    |> Chain.select_repo(api?: true).one()
  end
end
