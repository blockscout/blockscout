defmodule Indexer.Fetcher.Optimism.Deposit do
  @moduledoc """
  Fills op_deposits DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Explorer.Helper, only: [decode_data: 2]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Optimism.Deposit
  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Indexer.Fetcher.Optimism
  alias Indexer.Helper

  # 32-byte signature of the event TransactionDeposited(address indexed from, address indexed to, uint256 indexed version, bytes opaqueData)
  @transaction_deposited_event "0xb3813568d9991fc951961fcb4c784893574240a28925604d09fc577c55bb7c32"

  @fetcher_name :optimism_deposits
  @address_prefix "0x000000000000000000000000"

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl GenServer
  def handle_continue(:ok, _state) do
    Logger.metadata(fetcher: @fetcher_name)

    Optimism.init_continue(nil, __MODULE__)
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          contract_address: optimism_portal,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments,
          eth_get_logs_range_size: eth_get_logs_range_size
        } = state
      ) do
    # credo:disable-for-next-line
    time_before = Timex.now()

    transaction_type = Application.get_all_env(:indexer)[__MODULE__][:transaction_type]

    chunks_number = ceil((end_block - start_block + 1) / eth_get_logs_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    last_written_block =
      chunk_range
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = start_block + eth_get_logs_range_size * current_chunk
        chunk_end = min(chunk_start + eth_get_logs_range_size - 1, end_block)

        if chunk_end >= chunk_start do
          Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, :L1)

          {:ok, result} =
            Optimism.get_logs(
              chunk_start,
              chunk_end,
              optimism_portal,
              @transaction_deposited_event,
              json_rpc_named_arguments,
              Helper.infinite_retries_number()
            )

          deposit_events = prepare_events(result, transaction_type, json_rpc_named_arguments)

          {:ok, _} =
            Chain.import(%{
              optimism_deposits: %{params: deposit_events},
              timeout: :infinity
            })

          Publisher.broadcast(%{new_optimism_deposits: deposit_events}, :realtime)

          Helper.log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(deposit_events)} TransactionDeposited event(s)",
            :L1
          )
        end

        reorg_block = RollupReorgMonitorQueue.reorg_block_pop(__MODULE__)

        if !is_nil(reorg_block) && reorg_block > 0 do
          {deleted_count, _} = Repo.delete_all(from(d in Deposit, where: d.l1_block_number >= ^reorg_block))

          log_deleted_rows_count(reorg_block, deleted_count)

          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1

    {:ok, new_end_block} =
      Optimism.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number())

    delay =
      if new_end_block == last_written_block do
        # there is no new block, so wait for some time to let the chain issue the new block
        max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
      else
        0
      end

    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp log_deleted_rows_count(reorg_block, count) do
    if count > 0 do
      Logger.warning(
        "As L1 reorg was detected, all rows with l1_block_number >= #{reorg_block} were removed from the op_deposits table. Number of removed rows: #{count}."
      )
    end
  end

  defp prepare_events(events, transaction_type, json_rpc_named_arguments) do
    timestamps =
      events
      |> get_blocks_by_events(json_rpc_named_arguments, Helper.infinite_retries_number())
      |> Enum.reduce(%{}, fn block, acc ->
        block_number = quantity_to_integer(Map.get(block, "number"))
        {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
        Map.put(acc, block_number, timestamp)
      end)

    Enum.map(events, &event_to_deposit(&1, timestamps, transaction_type))
  end

  defp event_to_deposit(
         %{
           "blockHash" => "0x" <> stripped_block_hash,
           "blockNumber" => block_number_quantity,
           "transactionHash" => transaction_hash,
           "logIndex" => "0x" <> stripped_log_index,
           "topics" => [_, @address_prefix <> from_stripped, @address_prefix <> to_stripped, _],
           "data" => opaque_data
         },
         timestamps,
         transaction_type
       ) do
    {_, prefixed_block_hash} = (String.pad_leading("", 64, "0") <> stripped_block_hash) |> String.split_at(-64)
    {_, prefixed_log_index} = (String.pad_leading("", 64, "0") <> stripped_log_index) |> String.split_at(-64)

    deposit_id_hash =
      "#{prefixed_block_hash}#{prefixed_log_index}"
      |> Base.decode16!(case: :mixed)
      |> ExKeccak.hash_256()
      |> Base.encode16(case: :lower)

    source_hash =
      "#{String.pad_leading("", 64, "0")}#{deposit_id_hash}"
      |> Base.decode16!(case: :mixed)
      |> ExKeccak.hash_256()

    [
      <<
        msg_value::binary-size(32),
        value::binary-size(32),
        gas_limit::binary-size(8),
        _is_creation::binary-size(1),
        data::binary
      >>
    ] = decode_data(opaque_data, [:bytes])

    is_system = <<0>>

    rlp_encoded =
      ExRLP.encode(
        [
          source_hash,
          from_stripped |> Base.decode16!(case: :mixed),
          to_stripped |> Base.decode16!(case: :mixed),
          msg_value |> String.replace_leading(<<0>>, <<>>),
          value |> String.replace_leading(<<0>>, <<>>),
          gas_limit |> String.replace_leading(<<0>>, <<>>),
          is_system |> String.replace_leading(<<0>>, <<>>),
          data
        ],
        encoding: :hex
      )

    transaction_type =
      transaction_type
      |> Integer.to_string(16)
      |> String.downcase()

    l2_transaction_hash =
      "0x" <>
        ((transaction_type <> "#{rlp_encoded}")
         |> Base.decode16!(case: :mixed)
         |> ExKeccak.hash_256()
         |> Base.encode16(case: :lower))

    block_number = quantity_to_integer(block_number_quantity)

    %{
      l1_block_number: block_number,
      l1_block_timestamp: Map.get(timestamps, block_number),
      l1_transaction_hash: transaction_hash,
      l1_transaction_origin: "0x" <> from_stripped,
      l2_transaction_hash: l2_transaction_hash
    }
  end

  @doc """
    Determines the last saved L1 block number, the last saved transaction hash, and the transaction info for L1 Deposit events.

    Used by the `Indexer.Fetcher.Optimism` module to start fetching from a correct block number
    after reorg has occurred.

    ## Parameters
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
                                  Used to get transaction info by its hash from the RPC node.

    ## Returns
    - A tuple `{last_block_number, last_transaction_hash, last_transaction}` where
      `last_block_number` is the last block number found in the corresponding table (0 if not found),
      `last_transaction_hash` is the last transaction hash found in the corresponding table (nil if not found),
      `last_transaction` is the transaction info got from the RPC (nil if not found).
    - A tuple `{:error, message}` in case the `eth_getTransactionByHash` RPC request failed.
  """
  @spec get_last_l1_item(EthereumJSONRPC.json_rpc_named_arguments()) ::
          {non_neg_integer(), binary() | nil, map() | nil} | {:error, any()}
  def get_last_l1_item(json_rpc_named_arguments) do
    Optimism.get_last_item(
      :L1,
      &Deposit.last_deposit_l1_block_number_query/0,
      &Deposit.remove_deposits_query/1,
      json_rpc_named_arguments
    )
  end

  @doc """
    Returns L1 RPC URL for this module.
  """
  @spec l1_rpc_url() :: binary() | nil
  def l1_rpc_url do
    Optimism.l1_rpc_url()
  end

  @doc """
    Determines if `Indexer.Fetcher.RollupL1ReorgMonitor` module must be up
    before this fetcher starts.

    ## Returns
    - `true` if the reorg monitor must be active, `false` otherwise.
  """
  @spec requires_l1_reorg_monitor?() :: boolean()
  def requires_l1_reorg_monitor? do
    Optimism.requires_l1_reorg_monitor?()
  end

  defp get_blocks_by_events(events, json_rpc_named_arguments, retries) do
    request =
      events
      |> Enum.reduce(%{}, fn event, acc ->
        Map.put(acc, event["blockNumber"], 0)
      end)
      |> Stream.map(fn {block_number, _} -> %{number: block_number} end)
      |> Stream.with_index()
      |> Enum.into(%{}, fn {params, id} -> {id, params} end)
      |> Blocks.requests(&ByNumber.request(&1, false, false))

    error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

    case Optimism.repeated_request(request, error_message, json_rpc_named_arguments, retries) do
      {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
      {:error, _} -> []
    end
  end
end
