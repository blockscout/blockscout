defmodule Explorer.Chain.Cache.CeloEpochs do
  @moduledoc """
  Cache for efficiently mapping block numbers to epoch numbers in Celo blockchain.

  This implementation uses:
  1. A direct mathematical calculation for pre-migration epochs
  2. An ordered cache of post-migration epochs for efficient lookups
  """

  use Utils.RuntimeEnvHelper,
    l2_migration_block_number: [
      :explorer,
      [:celo, :l2_migration_block]
    ]

  use Explorer.Chain.OrderedCache,
    name: :celo_epochs_cache,
    # Adjust based on expected number of post-migration epochs
    max_size: 10000

  @type element :: %{
          number: non_neg_integer(),
          start_block_number: non_neg_integer(),
          end_block_number: non_neg_integer() | nil
        }

  @type id :: non_neg_integer()

  alias Explorer.Chain
  alias Explorer.Chain.Block
  alias Explorer.Chain.Cache.Blocks
  alias Explorer.Chain.Celo.{Epoch, Helper}
  alias Explorer.Repo

  alias Indexer.Fetcher.Celo.EpochBlockOperations.{
    EpochNumberByBlockNumber,
    EpochPeriod
  }

  import Ecto.Query, only: [from: 2]

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
      find_post_migration_epoch(block_number)
    end
  end

  @doc """
  Retrieves the epoch number of the last fetched block.
  """
  @spec last_block_epoch_number(Keyword.t()) :: Block.block_number() | nil
  def last_block_epoch_number(options \\ []) do
    block_number =
      1
      |> Blocks.atomic_take_enough()
      |> case do
        [%Block{number: number}] -> {:ok, number}
        nil -> Chain.max_consensus_block_number(options)
      end
      |> case do
        {:ok, number} -> number
        _ -> nil
      end

    block_number && block_number_to_epoch_number(block_number)
  end

  @spec find_post_migration_epoch(non_neg_integer()) :: non_neg_integer() | nil
  defp find_post_migration_epoch(block_number) do
    with {:cached, nil} <- {:cached, fetch_epoch_from_cache(block_number)},
         {:db, nil} <- {:db, fetch_epoch_from_db(block_number)},
         {:rpc, nil} <- {:rpc, fetch_epoch_from_rpc(block_number)} do
      nil
    else
      {method, epoch} ->
        # If the epoch is found in the database, update the cache
        if method in [:db, :rpc] do
          update(%{
            number: epoch.number,
            start_block_number: epoch.start_block_number,
            end_block_number: epoch.end_block_number
          })
        end

        epoch.number

      {:error, _} ->
        nil
    end
  end

  defp fetch_epoch_from_cache(block_number) do
    Enum.find(all(), fn epoch ->
      epoch.start_block_number <= block_number and
        block_number <= epoch.end_block_number
    end)
  end

  defp fetch_epoch_from_db(block_number) do
    from(e in Epoch,
      where:
        e.start_block_number <= ^block_number and
          ^block_number <= e.end_block_number,
      select: %{
        number: e.number,
        start_block_number: e.start_block_number,
        end_block_number: e.end_block_number
      }
    )
    |> Repo.one()
  end

  defp fetch_epoch_from_rpc(block_number) do
    with {:ok, epoch_number} <- EpochNumberByBlockNumber.fetch(block_number),
         {:ok, {start_block_number, end_block_number}} <- EpochPeriod.fetch(epoch_number) do
      %{
        number: epoch_number,
        start_block_number: start_block_number,
        end_block_number: end_block_number
      }
    else
      _ -> nil
    end
  end
end
