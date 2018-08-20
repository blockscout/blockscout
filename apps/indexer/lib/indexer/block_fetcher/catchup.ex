defmodule Indexer.BlockFetcher.Catchup do
  @moduledoc """
  Fetches and indexes block ranges from the block before the latest block to genesis (0) that are missing.
  """

  require Logger

  import Indexer, only: [debug: 1]
  import Indexer.BlockFetcher, only: [stream_fetch_and_import: 2]

  alias Explorer.Chain

  alias Indexer.{
    BalanceFetcher,
    BlockFetcher,
    BoundInterval,
    InternalTransactionFetcher,
    Sequence,
    TokenFetcher
  }

  @behaviour BlockFetcher

  @enforce_keys ~w(block_fetcher bound_interval)a
  defstruct ~w(block_fetcher bound_interval task)a

  def new(%{block_fetcher: %BlockFetcher{} = common_block_fetcher, block_interval: block_interval}) do
    block_fetcher = %BlockFetcher{common_block_fetcher | broadcast: false, callback_module: __MODULE__}
    minimum_interval = div(block_interval, 2)

    %__MODULE__{
      block_fetcher: block_fetcher,
      bound_interval: BoundInterval.within(minimum_interval..(minimum_interval * 10))
    }
  end

  @doc """
  Starts `task/1` and puts it in `t:Indexer.BlockFetcher.t/0`
  """
  @spec put(%BlockFetcher.Supervisor{catchup: %__MODULE__{task: nil}}) :: %BlockFetcher.Supervisor{
          catchup: %__MODULE__{task: Task.t()}
        }
  def put(%BlockFetcher.Supervisor{catchup: %__MODULE__{task: nil} = state} = supervisor_state) do
    put_in(
      supervisor_state.catchup.task,
      Task.Supervisor.async_nolink(Indexer.TaskSupervisor, __MODULE__, :task, [state])
    )
  end

  def task(%__MODULE__{
        block_fetcher:
          %BlockFetcher{blocks_batch_size: blocks_batch_size, json_rpc_named_arguments: json_rpc_named_arguments} =
            block_fetcher
      }) do
    {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)

    case latest_block_number do
      # let realtime indexer get the genesis block
      0 ->
        %{first_block_number: 0, missing_block_count: 0}

      _ ->
        # realtime indexer gets the current latest block
        first = latest_block_number - 1
        last = 0
        missing_ranges = Chain.missing_block_number_ranges(first..last)
        range_count = Enum.count(missing_ranges)

        missing_block_count =
          missing_ranges
          |> Stream.map(&Enum.count/1)
          |> Enum.sum()

        debug(fn -> "#{missing_block_count} missed blocks in #{range_count} ranges between #{first} and #{last}" end)

        case missing_block_count do
          0 ->
            :ok

          _ ->
            {:ok, sequence} = Sequence.start_link(ranges: missing_ranges, step: -1 * blocks_batch_size)
            Sequence.cap(sequence)

            stream_fetch_and_import(block_fetcher, sequence)
        end

        %{first_block_number: first, missing_block_count: missing_block_count}
    end
  end

  @async_import_remaning_block_data_options ~w(address_hash_to_fetched_balance_block_number transaction_hash_to_block_number)a

  @impl BlockFetcher
  def import(_, options) when is_map(options) do
    {async_import_remaning_block_data_options, chain_import_options} =
      Map.split(options, @async_import_remaning_block_data_options)

    with {:ok, results} = ok <- Chain.import(chain_import_options) do
      async_import_remaining_block_data(
        results,
        async_import_remaning_block_data_options
      )

      ok
    end
  end

  def handle_success(
        {ref, %{first_block_number: first_block_number, missing_block_count: missing_block_count}},
        %BlockFetcher.Supervisor{
          catchup: %__MODULE__{
            bound_interval: bound_interval,
            task: %Task{ref: ref}
          }
        } = supervisor_state
      )
      when is_integer(missing_block_count) do
    new_bound_interval =
      case missing_block_count do
        0 ->
          Logger.info("Index already caught up in #{first_block_number}-0")

          BoundInterval.increase(bound_interval)

        _ ->
          Logger.info("Index had to catch up #{missing_block_count} blocks in #{first_block_number}-0")

          BoundInterval.decrease(bound_interval)
      end

    Process.demonitor(ref, [:flush])

    interval = new_bound_interval.current

    Logger.info(fn ->
      "Checking if index needs to catch up in #{interval}ms"
    end)

    Process.send_after(self(), :catchup_index, interval)

    update_in(supervisor_state.catchup, fn state ->
      %__MODULE__{state | bound_interval: new_bound_interval, task: nil}
    end)
  end

  def handle_failure(
        {:DOWN, ref, :process, pid, reason},
        %BlockFetcher.Supervisor{catchup: %__MODULE__{task: %Task{pid: pid, ref: ref}}} = supervisor_state
      ) do
    Logger.error(fn -> "Catchup index stream exited with reason (#{inspect(reason)}). Restarting" end)

    send(self(), :catchup_index)

    put_in(supervisor_state.catchup.task, nil)
  end

  defp async_import_remaining_block_data(
         %{transactions: transaction_hashes, addresses: address_hashes, tokens: tokens},
         %{
           address_hash_to_fetched_balance_block_number: address_hash_to_block_number,
           transaction_hash_to_block_number: transaction_hash_to_block_number
         }
       ) do
    address_hashes
    |> Enum.map(fn address_hash ->
      block_number = Map.fetch!(address_hash_to_block_number, to_string(address_hash))
      %{address_hash: address_hash, block_number: block_number}
    end)
    |> BalanceFetcher.async_fetch_balances()

    transaction_hashes
    |> Enum.map(fn transaction_hash ->
      block_number = Map.fetch!(transaction_hash_to_block_number, to_string(transaction_hash))
      %{block_number: block_number, hash: transaction_hash}
    end)
    |> InternalTransactionFetcher.async_fetch(10_000)

    tokens
    |> Enum.map(& &1.contract_address_hash)
    |> TokenFetcher.async_fetch()
  end
end
