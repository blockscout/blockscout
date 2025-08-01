defmodule Explorer.Chain.Health.Helper do
  @moduledoc """
  Helper functions for /api/health endpoints
  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Chain.Block
  alias Explorer.Chain.Cache.Blocks, as: BlocksCache
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Repo

  @max_blocks_gap_between_node_and_db 20
  @no_new_items_error_code 5001
  @no_items_error_code 5002

  @doc """
  Fetches the status of the last block in the database.

  This function queries the database for the most recent block that has consensus.
  It returns a tuple indicating the status of the block:
    - `{:ok, block_number, timestamp}` if the block is found and is recent.
    - `{:stale, block_number, timestamp}` if the block is found but is considered stale.
    - `{:error, reason}` if there is an error in fetching the block.

  ## Examples

      iex> last_db_block_status()
      {:ok, 123456, ~U[2023-10-01 12:34:56Z]}

      iex> last_db_block_status()
      {:stale, 123456, ~U[2023-09-01 12:34:56Z]}

      iex> last_db_block_status()
      {:error, :not_found}

  """
  @spec last_db_block_status() ::
          {:ok, non_neg_integer(), DateTime.t()} | {:stale, non_neg_integer(), DateTime.t()} | {:error, atom}
  def last_db_block_status do
    last_db_block()
    |> block_status()
  end

  @spec last_db_block() ::
          {non_neg_integer(), DateTime.t()} | nil
  def last_db_block do
    query =
      from(block in Block,
        select: {block.number, block.timestamp},
        where: block.consensus == true,
        order_by: [desc: block.number],
        limit: 1
      )

    query
    |> Repo.one()
  end

  @doc """
  Retrieves the last cached block from the chain.

  ## Returns

  - A tuple containing the block number (non-negative integer) and the `DateTime` of the block.
  - `nil` if no blocks are found.

  ## Examples

      iex> Explorer.Chain.Health.Helper.last_cache_block()
      {123456, ~U[2023-10-05 14:30:00Z]}

  """
  @spec last_cache_block() ::
          {non_neg_integer(), DateTime.t()} | nil
  def last_cache_block do
    1
    |> BlocksCache.atomic_take_enough()
    |> case do
      [%{timestamp: timestamp, number: number}] ->
        {number, timestamp}

      nil ->
        nil
    end
  end

  @doc """
  Determines the status of a block based on its timestamp.

  ## Parameters

    - `block_info`: A tuple containing the block number and its timestamp, or `nil`.

  ## Returns

    - `{:ok, non_neg_integer(), DateTime.t()}` if the block is within the healthy period.
    - `{:stale, non_neg_integer(), DateTime.t()}` if the block is outside the healthy period.
    - `{:error, atom}` if the input is `nil`.

  The healthy period is defined by the `:healthy_blocks_period` configuration in the `:explorer` application for `Explorer.Chain.Health.Monitor` module.
  """
  @spec block_status({non_neg_integer(), DateTime.t()} | nil) ::
          {:ok, non_neg_integer(), DateTime.t()} | {:stale, non_neg_integer(), DateTime.t()} | {:error, atom}
  def block_status({number, timestamp}) do
    now = DateTime.utc_now()
    last_block_period = DateTime.diff(now, timestamp, :millisecond)

    if last_block_period > Application.get_env(:explorer, Explorer.Chain.Health.Monitor)[:healthy_blocks_period] do
      {:stale, number, timestamp}
    else
      {:ok, number, timestamp}
    end
  end

  def block_status(nil), do: {:error, :no_blocks}

  @doc """
  Fetches and returns the latest Blockscout indexing health data.

  This function retrieves multiple values related to the latest block indexing health from the `LastFetchedCounter` module. The keys for the values are:
    - "health_latest_block_number_from_cache"
    - "health_latest_block_timestamp_from_cache"
    - "health_latest_block_number_from_db"
    - "health_latest_block_timestamp_from_db"
    - "health_latest_block_number_from_node"
    - "health_latest_batch_number_from_db",
    - "health_latest_batch_timestamp_from_db"
    - "health_latest_batch_average_time_from_db"

  The retrieved values are then reduced into a map with the following keys:
    - `:health_latest_block_number_from_db`
    - `:health_latest_block_timestamp_from_db`
    - `:health_latest_block_number_from_cache`
    - `:health_latest_block_timestamp_from_cache`
    - `:health_latest_block_number_from_node`
    - `:health_latest_batch_number_from_db`
    - `:health_latest_batch_timestamp_from_db`
    - `:health_latest_batch_average_time_from_db`

  Each key in the map is assigned the corresponding value fetched from the `LastFetchedCounter`.

  ## Returns
  - A map containing the latest block indexing health data.
  """
  @spec get_indexing_health_data() :: map()
  def get_indexing_health_data do
    values =
      LastFetchedCounter.get_multiple([
        "health_latest_block_number_from_cache",
        "health_latest_block_timestamp_from_cache",
        "health_latest_block_number_from_db",
        "health_latest_block_timestamp_from_db",
        "health_latest_block_number_from_node",
        "health_latest_batch_number_from_db",
        "health_latest_batch_timestamp_from_db",
        "health_latest_batch_average_time_from_db"
      ])

    values
    |> Enum.reduce(
      %{
        health_latest_block_number_from_db: nil,
        health_latest_block_timestamp_from_db: nil,
        health_latest_block_number_from_cache: nil,
        health_latest_block_timestamp_from_cache: nil,
        health_latest_block_number_from_node: nil,
        health_latest_batch_number_from_db: nil,
        health_latest_batch_timestamp_from_db: nil,
        health_latest_batch_average_time_from_db: nil
      },
      fn {key, value}, acc ->
        Map.put(acc, String.to_existing_atom(key), value)
      end
    )
  end

  @spec blocks_indexing_healthy?(map() | nil) :: boolean() | {boolean(), non_neg_integer(), binary()}
  def blocks_indexing_healthy?(nil), do: true

  def blocks_indexing_healthy?(health_status) do
    if health_status[:health_latest_block_timestamp_from_db] do
      last_block_db_delay = get_last_item_delay(health_status, :health_latest_block_timestamp_from_db)

      blocks_indexing_delay_threshold =
        Application.get_env(:explorer, Explorer.Chain.Health.Monitor)[:healthy_blocks_period]

      with true <- last_block_db_delay > blocks_indexing_delay_threshold,
           {:empty_health_latest_block_number_from_node, false} <-
             {:empty_health_latest_block_number_from_node, is_nil(health_status.health_latest_block_number_from_node)},
           true <-
             Decimal.compare(
               Decimal.sub(
                 health_status.health_latest_block_number_from_node,
                 health_status.health_latest_block_number_from_db
               ),
               Decimal.new(@max_blocks_gap_between_node_and_db)
             ) == :gt do
        no_new_block_status(last_block_db_delay)
      else
        {:empty_health_latest_block_number_from_node, true} -> no_new_block_status(last_block_db_delay)
        _ -> true
      end
    else
      {false, @no_items_error_code, "There are no blocks in the DB."}
    end
  end

  defp no_new_block_status(last_block_db_delay) do
    {false, @no_new_items_error_code,
     "There are no new blocks in the DB for the last #{round(last_block_db_delay / 1_000 / 60)} mins. Check the healthiness of the JSON RPC archive node or the DB."}
  end

  @spec batches_indexing_healthy?(map() | nil) :: boolean() | {boolean(), non_neg_integer(), binary()}
  def batches_indexing_healthy?(nil), do: true

  def batches_indexing_healthy?(health_status) do
    if health_status[:health_latest_batch_timestamp_from_db] do
      last_batch_db_delay = get_last_item_delay(health_status, :health_latest_batch_timestamp_from_db)

      batches_indexing_delay_threshold =
        Application.get_env(:explorer, Explorer.Chain.Health.Monitor)[:healthy_batches_period]

      if last_batch_db_delay > batches_indexing_delay_threshold do
        {false, @no_new_items_error_code,
         "There are no new batches in the DB for the last #{round(last_batch_db_delay / 1_000 / 60)} mins."}
      else
        true
      end
    else
      {false, @no_items_error_code, "There are no batches in the DB."}
    end
  end

  defp get_last_item_delay(health_status, item_timestamp_key) do
    {:ok, latest_item_timestamp} =
      DateTime.from_unix(Decimal.to_integer(health_status[item_timestamp_key]))

    now = DateTime.utc_now()
    DateTime.diff(now, latest_item_timestamp, :millisecond)
  end
end
