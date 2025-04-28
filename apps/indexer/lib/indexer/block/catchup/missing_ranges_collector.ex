defmodule Indexer.Block.Catchup.MissingRangesCollector do
  @moduledoc """
  Collects and manages missing block ranges in the blockchain.

  This module implements a GenServer that identifies and tracks blocks that haven't
  been indexed yet. It supports different scanning strategies based on configuration:

  ## Scanning Strategies

  Both scanning strategies operate as continuous processes that work through iterations,
  but they differ in how they initialize and progress through the blockchain:

  - **Bidirectional scanning** - Used when either no block ranges are configured or
    when using a single range ending with "latest" (e.g., "0..latest"). This strategy:
    * Initially populates the database with a single batch of missing blocks (limited
      by `batch_size`, default 100,000) starting from the current blockchain height
      and working backward
    * Maintains two boundaries in the server state: `min_fetched_block_number` for
      backward scanning toward genesis, and `max_fetched_block_number` for forward
      scanning toward the current chain head
    * During each scanning iteration:
      - Calculates a range of blocks to examine (either backward from `min_fetched_block_number`
        or forward from `max_fetched_block_number`)
      - Queries the blockchain to identify which specific blocks are missing within that range
      - Consolidates adjacent missing blocks into compact ranges for efficient storage
      - Inserts these identified missing block ranges into the database
      - Updates the appropriate boundary in the state for the next iteration
    * Alternates between backward and forward scanning directions with different timing
      intervals (10ms for initial backward scanning, 1 minute for subsequent scans)
    * Completes initial phase when reaching the configured first block, then continues
      with primarily forward scanning for new blocks

  - **Range-specific scanning** - Used when specific finite ranges or multiple ranges
    are configured. This strategy:
    * Clears all existing missing block ranges from the database
    * For each configured range (e.g., "100..200,1000..9000"), identifies all missing
      blocks within those ranges by querying the blockchain
    * Saves all identified missing ranges to the database in a single batch operation
    * When a range ends with "latest" (except for a single "X..latest" range), only
      schedules forward scanning from the highest point of the explicit ranges
    * Only scans within the specific ranges, ignoring blocks outside these boundaries

  ## Configuration

  The behavior is controlled through application configuration:

  - `:block_ranges` - A comma-separated string of block ranges (e.g., "0..1000,2000..latest").
    When set to a single range ending with "latest" (e.g., "0..latest"), it behaves
    like no ranges are configured, using the more efficient bidirectional approach.

  - `:first_block` - The lowest block number to consider for scanning.

  - `:last_block` - If set, defines the upper boundary for scanning. If not set,
    scanning continues indefinitely as the blockchain grows.

  - `:batch_size` - The maximum number of blocks to process in each scanning iteration.
    This limits how many blocks are examined for missing entries in a single pass
    (default 100,000) and applies to both backward and forward scanning operations.
  """

  use GenServer
  use Utils.CompileTimeEnvHelper, future_check_interval: [:indexer, [__MODULE__, :future_check_interval]]

  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.{Chain, Helper, Repo}
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Utility.{MissingBlockRange, MissingRangesManipulator}

  @default_missing_ranges_batch_size 100_000
  @past_check_interval 10
  @increased_past_check_interval :timer.minutes(1)

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{min_fetched_block_number: nil, max_fetched_block_number: nil}, {:continue, :ok}}
  end

  @impl true
  def handle_continue(:ok, _state) do
    {:noreply, define_init()}
  end

  # Determines and initializes the appropriate missing block range collection state.
  #
  # Checks the application configuration for block ranges and initializes the state
  # accordingly:
  # - If no ranges are configured, plans for full chain scanning
  # - If ranges are configured, parses them and initializes based on the type:
  #   * For invalid or empty ranges, plans for full chain scanning
  #   * For a single range ending with "latest" (e.g., "0..latest" or "X..latest"),
  #     plans for full chain scanning with bidirectional scanning similar to when
  #     no ranges are configured
  #   * For finite ranges, plans for scanning with the specified block ranges
  #   * For multiple ranges where at least one ends with "latest", plans for scanning
  #     with the ranges and every block after the lowest one in the range with the
  #     open range
  #
  # ## Returns
  # A map containing:
  # - `max_fetched_block_number`: The highest block number to collect up to
  # - `first_check_completed?`: Set to `false` to indicate initial check is pending
  # - `min_fetched_block_number`: Optional lowest block number to start from
  @spec define_init() :: %{
          :max_fetched_block_number => non_neg_integer(),
          :first_check_completed? => boolean(),
          optional(:min_fetched_block_number) => non_neg_integer()
        }
  defp define_init do
    case Application.get_env(:indexer, :block_ranges) do
      nil ->
        default_init()

      string_ranges ->
        case parse_block_ranges(string_ranges) do
          :no_ranges -> default_init()
          # "100-200" or "100..200,300..400"
          {:finite_ranges, ranges} -> ranges_init(ranges)
          # "<X>..latest"
          {:infinite_ranges, [], _} -> default_init()
          # "100..200,300..latest"
          {:infinite_ranges, ranges, max_fetched_block_number} -> ranges_init(ranges, max_fetched_block_number)
        end
    end
  end

  # Initializes the default state for missing block range collection.
  #
  # Performs the following initialization steps:
  # 1. Gets initial block range boundaries including inserting the first batch of
  #    missing ranges into the database
  # 2. Adjusts ranges to respect blockchain boundaries
  # 3. Schedules both future and initial past block checks
  #
  # This function is called when no block ranges are configured or when the
  # configured ranges are invalid.
  #
  # ## Returns
  # A map containing:
  # - `min_fetched_block_number`: The lowest block number to start collecting from
  # - `max_fetched_block_number`: The highest block number to collect up to
  # - `first_check_completed?: boolean()
  @spec default_init() :: %{
          min_fetched_block_number: non_neg_integer(),
          max_fetched_block_number: non_neg_integer(),
          first_check_completed?: boolean()
        }
  defp default_init do
    {min_number, max_number} = get_initial_min_max()

    clear_to_bounds(min_number, max_number)

    schedule_future_check()
    schedule_past_check(false)

    %{min_fetched_block_number: min_number, max_fetched_block_number: max_number, first_check_completed?: false}
  end

  # Initializes the missing block ranges system with a predefined set of ranges.
  #
  # Performs the following steps:
  # 1. Clears all existing missing block ranges from the database
  # 2. Identifies missing blocks within each range and saves the new identified
  #    ranges of missing blocks to the database
  # 3. If `max_fetched_block_number` is provided, schedules future block checks
  #
  # ## Parameters
  # - `ranges`: List of `Range` structs defining the block ranges to initialize
  # - `max_fetched_block_number`: Optional highest block number processed, used for
  #   scheduling future checks
  #
  # ## Returns
  # A map containing:
  # - `max_fetched_block_number`: The provided max block number or nil
  # - `first_check_completed?`: Set to `false` to indicate initial check is pending
  @spec ranges_init(list(Range.t()), non_neg_integer() | nil) :: %{
          max_fetched_block_number: non_neg_integer(),
          first_check_completed?: boolean()
        }
  defp ranges_init(ranges, max_fetched_block_number \\ nil) do
    Repo.delete_all(MissingBlockRange)

    ranges
    |> Enum.reverse()
    |> Enum.flat_map(fn f..l//_ -> Chain.missing_block_number_ranges(l..f) end)
    |> MissingRangesManipulator.save_batch()

    if not is_nil(max_fetched_block_number) do
      schedule_future_check()
    end

    %{max_fetched_block_number: max_fetched_block_number, first_check_completed?: false}
  end

  # Adjusts the missing block ranges to respect the given boundary constraints.
  #
  # Processes both the lower and upper boundaries of the missing block ranges:
  # - For the lower bound: If `min_number` is below `first_block()`:
  #   * Removes all ranges that start below the first block
  #   * Updates any range containing the first block to start at the first block
  # - For the upper bound: If `max_number` is above `last_block() - 1`:
  #   * Removes all ranges that end above the last block
  #   * Updates any range containing the last block to end at the last block
  #
  # This ensures that missing block ranges stay within valid blockchain boundaries
  # and prevents tracking blocks outside the configured or available range.
  #
  # ## Parameters
  # - `min_number`: The lower boundary for missing block ranges
  # - `max_number`: The upper boundary for missing block ranges
  defp clear_to_bounds(min_number, max_number) do
    first = first_block()
    last = last_block() - 1

    if min_number < first do
      first
      |> MissingBlockRange.from_number_below_query()
      |> Repo.delete_all()

      first
      |> MissingBlockRange.include_bound_query()
      |> Repo.one()
      |> case do
        nil ->
          :ok

        range ->
          range
          |> MissingBlockRange.changeset(%{to_number: first})
          |> Repo.update()
      end
    end

    if max_number > last do
      last
      |> MissingBlockRange.to_number_above_query()
      |> Repo.delete_all()

      last
      |> MissingBlockRange.include_bound_query()
      |> Repo.one()
      |> case do
        nil ->
          :ok

        range ->
          range
          |> MissingBlockRange.changeset(%{from_number: last})
          |> Repo.update()
      end
    end
  end

  # Determines the initial boundaries for missing block range collection.
  #
  # Fetches the current minimum and maximum block numbers from the missing block ranges:
  # - If no ranges exist (min and max are nil), creates an initial batch:
  #   * Uses the last block number from the configuration or fetches the maximum
  #     block number from the blockchain if not configured as the maximum boundary
  #   * Fetches a batch of missing ranges backwards from that point
  #   * Returns the new minimum boundary and the last block as boundaries
  # - If ranges exist, returns their minimum and maximum bounds directly
  #
  # ## Returns
  # A tuple `{min, max}` where:
  # - `min`: The lowest block number to start collecting from
  # - `max`: The highest block number to collect up to
  @spec get_initial_min_max() :: {non_neg_integer(), non_neg_integer()}
  defp get_initial_min_max do
    case MissingBlockRange.fetch_min_max() do
      %{min: nil, max: nil} ->
        max_number = last_block()
        {min_number, first_batch} = fetch_missing_ranges_batch(max_number, false)
        MissingRangesManipulator.save_batch(first_batch)
        {min_number, max_number}

      %{min: min, max: max} ->
        {min, max}
    end
  end

  # Processes the next batch of future missing blocks when triggered by the scheduled check.
  #
  # If future updating should continue:
  # - Fetches the next batch of missing blocks moving forward
  # - Saves the identified missing ranges to the database
  # - Schedules the next future check
  # - Updates the state with the new maximum block number
  #
  # The process stops when the configured last block is reached or continues
  # indefinitely if no last block is configured.
  @impl true
  def handle_info(:update_future, %{max_fetched_block_number: max_number} = state) do
    if continue_future_updating?(max_number) do
      {new_max_number, batch} = fetch_missing_ranges_batch(max_number, true)
      MissingRangesManipulator.save_batch(batch)
      schedule_future_check()
      {:noreply, %{state | max_fetched_block_number: new_max_number}}
    else
      {:noreply, state}
    end
  end

  # Processes the next batch of past missing blocks when triggered by the scheduled check.
  #
  # If the current minimum block number is above first_block():
  # - Fetches the next batch of missing blocks moving backward
  # - Saves the identified missing ranges to the database
  # - Schedules the next past check based on whether initial check is completed
  # - Updates the state with the new minimum block number
  #
  # When reaching first_block():
  # - Marks the initial check as completed
  # - Resets min_fetched_block_number to max_fetched_block_number
  # - Schedules future checks at increased intervals
  @impl true
  def handle_info(:update_past, %{min_fetched_block_number: min_number} = state) do
    if min_number > first_block() do
      {new_min_number, batch} = fetch_missing_ranges_batch(min_number, false)
      MissingRangesManipulator.save_batch(batch)
      schedule_past_check(state.first_check_completed?)
      {:noreply, %{state | min_fetched_block_number: new_min_number}}
    else
      schedule_past_check(true)
      {:noreply, %{state | min_fetched_block_number: state.max_fetched_block_number, first_check_completed?: true}}
    end
  end

  # Fetches a batch of missing block ranges in either forward or backward direction.
  #
  # When `to_future?` is false, searches backwards from the given block number
  # towards `first_block()`. When true, searches forwards from the given block
  # towards `last_block()`. The batch size is determined by `missing_ranges_batch_size()`.
  #
  # ## Parameters
  # - `min_or_max_block`: The block number to start searching from
  # - `to_future?`: Direction of search - `true` for forward, `false` for backward
  #
  # ## Returns
  # - `{new_boundary, ranges}` where:
  #   - `new_boundary`: The new search boundary for the next batch
  #   - `ranges`: List of ranges representing missing blocks in the searched interval
  @spec fetch_missing_ranges_batch(non_neg_integer(), boolean()) :: {non_neg_integer(), [Range.t()]}
  defp fetch_missing_ranges_batch(min_or_max_block, to_future?)

  defp fetch_missing_ranges_batch(min_fetched_block_number, false = _to_future?) do
    from = min_fetched_block_number - 1
    to = max(min_fetched_block_number - missing_ranges_batch_size(), first_block())

    if from >= to do
      {to, Chain.missing_block_number_ranges(from..to)}
    else
      {min_fetched_block_number, []}
    end
  end

  defp fetch_missing_ranges_batch(max_fetched_block_number, true) do
    to = max_fetched_block_number + 1
    from = min(max_fetched_block_number + missing_ranges_batch_size(), last_block() - 1)

    if from >= to do
      {from, Chain.missing_block_number_ranges(from..to)}
    else
      {max_fetched_block_number, []}
    end
  end

  # Determines the lowest block number to start collecting missing ranges from.
  #
  # Takes the maximum between:
  # - The minimum block number from the configured block ranges
  # - The last recorded minimum missing block number from the database
  @spec first_block() :: non_neg_integer()
  defp first_block do
    first_block_from_config =
      RangesHelper.get_min_block_number_from_range_string(Application.get_env(:indexer, :block_ranges))

    min_missing_block_number =
      "min_missing_block_number"
      |> LastFetchedCounter.get()
      |> Decimal.to_integer()

    max(first_block_from_config, min_missing_block_number)
  end

  # Retrieves the last block number from configuration or fetches the maximum
  # block number from the blockchain if not configured.
  @spec last_block() :: non_neg_integer()
  defp last_block do
    last_block = Application.get_env(:indexer, :last_block)
    if last_block, do: last_block + 1, else: fetch_max_block_number_from_node()
  end

  # Retrieves the highest block number from blockchain.
  @spec fetch_max_block_number_from_node() :: non_neg_integer()
  defp fetch_max_block_number_from_node do
    json_rpc_named_arguments = Application.get_env(:indexer, :json_rpc_named_arguments)

    case EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments) do
      {:ok, number} -> number
      _ -> 0
    end
  end

  # Determines if future block checks should continue based on the configured last
  # block or defaults to true if none set
  defp continue_future_updating?(max_fetched_block_number) do
    last_block = Application.get_env(:indexer, :last_block)

    if last_block do
      max_fetched_block_number < last_block
    else
      true
    end
  end

  # Schedules the next check for missing blocks in past ranges.
  #
  # Sets up a timer to trigger an `:update_past` message after a configurable interval:
  # - Uses `@past_check_interval` (10ms) for the initial check
  # - Uses `@increased_past_check_interval` (1 minute) for subsequent checks
  #
  # The different intervals optimize the initial catchup while preventing excessive
  # database load during normal operation.
  #
  # ## Parameters
  # - `first_check_completed?`: Boolean indicating if the initial check has been completed
  defp schedule_past_check(first_check_completed?) do
    interval = if first_check_completed?, do: @increased_past_check_interval, else: @past_check_interval

    Process.send_after(self(), :update_past, interval)
  end

  # Schedules the next check for missing blocks in future ranges.
  #
  # Sets up a timer to trigger an `:update_future` message after the configured
  # `@future_check_interval` (1 minute by default).
  defp schedule_future_check do
    Process.send_after(self(), :update_future, @future_check_interval)
  end

  defp missing_ranges_batch_size do
    Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_missing_ranges_batch_size
  end

  @doc """
    Parses a comma-separated string of block ranges into a structured format.

    Processes ranges in the format "from..to" or "from..latest", where:
    - Regular ranges are converted to `from..to` Range structs
    - "latest" ranges are converted to single integers
    - Invalid ranges are filtered out during sanitization

    The ranges are sanitized to merge adjacent or overlapping ranges and remove
    empty ones.

    ## Parameters
    - `block_ranges_string`: A comma-separated string of block ranges (e.g. "1..100,200..300,400..latest")

    ## Returns
    One of:
    - `{:finite_ranges, ranges}` - When all ranges are finite (e.g. "1..100,200..300")
    - `{:infinite_ranges, ranges, last_num}` - When the last range ends with "latest"
    - `:no_ranges` - When no valid ranges are found

    ## Examples
        iex> parse_block_ranges("1..100,200..300")
        {:finite_ranges, [1..100, 200..300]}

        iex> parse_block_ranges("1..100,200..latest")
        {:infinite_ranges, [1..100], 200}

        iex> parse_block_ranges("invalid")
        :no_ranges
  """
  @spec parse_block_ranges(binary()) ::
          {:finite_ranges, [Range.t()]} | {:infinite_ranges, [Range.t()], non_neg_integer()} | :no_ranges
  def parse_block_ranges(block_ranges_string) do
    ranges =
      block_ranges_string
      |> String.split(",")
      |> Enum.map(fn string_range ->
        case String.split(string_range, "..") do
          [from_string, "latest"] ->
            Helper.parse_integer(from_string)

          [from_string, to_string] ->
            get_from_to(from_string, to_string)

          _ ->
            nil
        end
      end)
      |> RangesHelper.sanitize_ranges()

    case List.last(ranges) do
      _from.._to//_ ->
        {:finite_ranges, ranges}

      nil ->
        :no_ranges

      num ->
        {:infinite_ranges, List.delete_at(ranges, -1), num - 1}
    end
  end

  # Creates a range from string boundaries, returning nil if parsing fails or if from > to
  @spec get_from_to(binary(), binary()) :: Range.t() | nil
  defp get_from_to(from_string, to_string) do
    with {from, ""} <- Integer.parse(from_string),
         {to, ""} <- Integer.parse(to_string) do
      if from <= to, do: from..to, else: nil
    else
      _ -> nil
    end
  end
end
