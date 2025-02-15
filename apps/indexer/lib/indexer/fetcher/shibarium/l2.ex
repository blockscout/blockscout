defmodule Indexer.Fetcher.Shibarium.L2 do
  @moduledoc """
  Fills shibarium_bridge DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC,
    only: [
      id_to_params: 1,
      json_rpc: 2,
      quantity_to_integer: 1,
      request: 1
    ]

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  import Explorer.Helper, only: [decode_data: 2, parse_integer: 1]

  import Indexer.Fetcher.Shibarium.Helper,
    only: [calc_operation_hash: 5, prepare_insert_items: 2, recalculate_cached_count: 0]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.{Blocks, Logs, Receipt}
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Shibarium.Bridge
  alias Indexer.Helper
  alias Indexer.Transform.Addresses

  @eth_get_logs_range_size 100
  @fetcher_name :shibarium_bridge_l2
  @empty_hash "0x0000000000000000000000000000000000000000000000000000000000000000"

  # 32-byte signature of the event TokenDeposited(address indexed rootToken, address indexed childToken, address indexed user, uint256 amount, uint256 depositCount)
  @token_deposited_event "0xec3afb067bce33c5a294470ec5b29e6759301cd3928550490c6d48816cdc2f5d"

  # 32-byte signature of the event Transfer(address indexed from, address indexed to, uint256 value)
  @transfer_event "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  # 32-byte signature of the event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value)
  @transfer_single_event "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62"

  # 32-byte signature of the event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values)
  @transfer_batch_event "0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb"

  # 32-byte signature of the event Withdraw(address indexed rootToken, address indexed from, uint256 amount, uint256, uint256)
  @withdraw_event "0xebff2602b3f468259e1e99f613fed6691f3a6526effe6ef3e768ba7ae7a36c4f"

  # 4-byte signature of the method withdraw(uint256 amount)
  @withdraw_method "0x2e1a7d4d"

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
  def init(args) do
    json_rpc_named_arguments = args[:json_rpc_named_arguments]
    {:ok, %{}, {:continue, json_rpc_named_arguments}}
  end

  @impl GenServer
  def handle_continue(json_rpc_named_arguments, _state) do
    Logger.metadata(fetcher: @fetcher_name)
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :init_with_delay, 2000)
    {:noreply, %{json_rpc_named_arguments: json_rpc_named_arguments}}
  end

  @impl GenServer
  def handle_info(:init_with_delay, %{json_rpc_named_arguments: json_rpc_named_arguments} = state) do
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_undefined, false} <- {:start_block_undefined, is_nil(env[:start_block])},
         {:child_chain_address_is_valid, true} <-
           {:child_chain_address_is_valid, Helper.address_correct?(env[:child_chain])},
         {:weth_address_is_valid, true} <- {:weth_address_is_valid, Helper.address_correct?(env[:weth])},
         {:bone_withdraw_address_is_valid, true} <-
           {:bone_withdraw_address_is_valid, Helper.address_correct?(env[:bone_withdraw])},
         start_block = parse_integer(env[:start_block]),
         false <- is_nil(start_block),
         true <- start_block > 0,
         {last_l2_block_number, last_l2_transaction_hash} <- get_last_l2_item(),
         {:ok, latest_block} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments),
         {:start_block_valid, true} <-
           {:start_block_valid,
            (start_block <= last_l2_block_number || last_l2_block_number == 0) && start_block <= latest_block},
         {:ok, last_l2_transaction} <-
           Helper.get_transaction_by_hash(last_l2_transaction_hash, json_rpc_named_arguments),
         {:l2_transaction_not_found, false} <-
           {:l2_transaction_not_found, !is_nil(last_l2_transaction_hash) && is_nil(last_l2_transaction)} do
      recalculate_cached_count()

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         start_block: max(start_block, last_l2_block_number),
         latest_block: latest_block,
         child_chain: String.downcase(env[:child_chain]),
         weth: String.downcase(env[:weth]),
         bone_withdraw: String.downcase(env[:bone_withdraw]),
         json_rpc_named_arguments: json_rpc_named_arguments
       }}
    else
      {:start_block_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, state}

      {:child_chain_address_is_valid, false} ->
        Logger.error("ChildChain contract address is invalid or not defined.")
        {:stop, :normal, state}

      {:weth_address_is_valid, false} ->
        Logger.error("WETH contract address is invalid or not defined.")
        {:stop, :normal, state}

      {:bone_withdraw_address_is_valid, false} ->
        Logger.error("Bone Withdraw contract address is invalid or not defined.")
        {:stop, :normal, state}

      {:start_block_valid, false} ->
        Logger.error("Invalid L2 Start Block value. Please, check the value and shibarium_bridge table.")
        {:stop, :normal, state}

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L2 transaction by its hash or latest block from RPC due to RPC error: #{inspect(error_data)}"
        )

        {:stop, :normal, state}

      {:l2_transaction_not_found, true} ->
        Logger.error(
          "Cannot find last L2 transaction from RPC by its hash. Probably, there was a reorg on L2 chain. Please, check shibarium_bridge table."
        )

        {:stop, :normal, state}

      _ ->
        Logger.error("L2 Start Block is invalid or zero.")
        {:stop, :normal, state}
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          start_block: start_block,
          latest_block: end_block,
          child_chain: child_chain,
          weth: weth,
          bone_withdraw: bone_withdraw,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    start_block..end_block
    |> Enum.chunk_every(@eth_get_logs_range_size)
    |> Enum.each(fn current_chunk ->
      chunk_start = List.first(current_chunk)
      chunk_end = List.last(current_chunk)

      Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, :L2)

      operations =
        chunk_start..chunk_end
        |> get_logs_all(child_chain, bone_withdraw, json_rpc_named_arguments)
        |> prepare_operations(weth)

      insert_items = prepare_insert_items(operations, __MODULE__)

      addresses =
        Addresses.extract_addresses(%{
          shibarium_bridge_operations: insert_items
        })

      {:ok, _} =
        Chain.import(%{
          addresses: %{params: addresses, on_conflict: :nothing},
          shibarium_bridge_operations: %{params: insert_items},
          timeout: :infinity
        })

      Helper.log_blocks_chunk_handling(
        chunk_start,
        chunk_end,
        start_block,
        end_block,
        "#{Enum.count(operations)} L2 operation(s)",
        :L2
      )
    end)

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def filter_deposit_events(events, child_chain) do
    Enum.filter(events, fn event ->
      address = String.downcase(event.address_hash)
      first_topic = Helper.log_topic_to_string(event.first_topic)
      second_topic = Helper.log_topic_to_string(event.second_topic)
      third_topic = Helper.log_topic_to_string(event.third_topic)
      fourth_topic = Helper.log_topic_to_string(event.fourth_topic)

      (first_topic == @token_deposited_event and address == child_chain) or
        (first_topic == @transfer_event and second_topic == @empty_hash and third_topic != @empty_hash) or
        (Enum.member?([@transfer_single_event, @transfer_batch_event], first_topic) and
           third_topic == @empty_hash and fourth_topic != @empty_hash)
    end)
  end

  def filter_withdrawal_events(events, bone_withdraw) do
    Enum.filter(events, fn event ->
      address = String.downcase(event.address_hash)
      first_topic = Helper.log_topic_to_string(event.first_topic)
      second_topic = Helper.log_topic_to_string(event.second_topic)
      third_topic = Helper.log_topic_to_string(event.third_topic)
      fourth_topic = Helper.log_topic_to_string(event.fourth_topic)

      (first_topic == @withdraw_event and address == bone_withdraw) or
        (first_topic == @transfer_event and second_topic != @empty_hash and third_topic == @empty_hash) or
        (Enum.member?([@transfer_single_event, @transfer_batch_event], first_topic) and
           third_topic != @empty_hash and fourth_topic == @empty_hash)
    end)
  end

  def prepare_operations({events, timestamps}, weth) do
    events
    |> Enum.map(&prepare_operation(&1, timestamps, weth))
    |> List.flatten()
  end

  def reorg_handle(reorg_block) do
    {deleted_count, _} =
      Repo.delete_all(from(sb in Bridge, where: sb.l2_block_number >= ^reorg_block and is_nil(sb.l1_transaction_hash)))

    {updated_count1, _} =
      Repo.update_all(
        from(sb in Bridge,
          where:
            sb.l2_block_number >= ^reorg_block and not is_nil(sb.l1_transaction_hash) and
              sb.operation_type == :withdrawal
        ),
        set: [timestamp: nil]
      )

    {updated_count2, _} =
      Repo.update_all(
        from(sb in Bridge, where: sb.l2_block_number >= ^reorg_block and not is_nil(sb.l1_transaction_hash)),
        set: [l2_transaction_hash: nil, l2_block_number: nil]
      )

    updated_count = max(updated_count1, updated_count2)

    if deleted_count > 0 or updated_count > 0 do
      recalculate_cached_count()

      Logger.warning(
        "As L2 reorg was detected, some rows with l2_block_number >= #{reorg_block} were affected (removed or updated) in the shibarium_bridge table. Number of removed rows: #{deleted_count}. Number of updated rows: >= #{updated_count}."
      )
    end
  end

  def withdraw_method_signature do
    @withdraw_method
  end

  defp get_blocks_by_range(range, json_rpc_named_arguments, retries) do
    request =
      range
      |> Stream.map(fn block_number -> %{number: block_number} end)
      |> id_to_params()
      |> Blocks.requests(&ByNumber.request(&1))

    error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

    case Helper.repeated_call(&json_rpc/2, [request, json_rpc_named_arguments], error_message, retries) do
      {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
      {:error, _} -> []
    end
  end

  defp get_last_l2_item do
    query =
      from(sb in Bridge,
        select: {sb.l2_block_number, sb.l2_transaction_hash},
        where: not is_nil(sb.l2_block_number),
        order_by: [desc: sb.l2_block_number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  defp get_logs_all(block_range, child_chain, bone_withdraw, json_rpc_named_arguments) do
    blocks = get_blocks_by_range(block_range, json_rpc_named_arguments, Helper.infinite_retries_number())

    deposit_logs = get_deposit_logs_from_receipts(blocks, child_chain, json_rpc_named_arguments)

    withdrawal_logs = get_withdrawal_logs_from_receipts(blocks, bone_withdraw, json_rpc_named_arguments)

    timestamps =
      blocks
      |> Enum.reduce(%{}, fn block, acc ->
        block_number =
          block
          |> Map.get("number")
          |> quantity_to_integer()

        {:ok, timestamp} =
          block
          |> Map.get("timestamp")
          |> quantity_to_integer()
          |> DateTime.from_unix()

        Map.put(acc, block_number, timestamp)
      end)

    {deposit_logs ++ withdrawal_logs, timestamps}
  end

  defp get_deposit_logs_from_receipts(blocks, child_chain, json_rpc_named_arguments) do
    blocks
    |> Enum.reduce([], fn block, acc ->
      hashes =
        block
        |> Map.get("transactions", [])
        |> Enum.filter(fn t -> Map.get(t, "from") == burn_address_hash_string() end)
        |> Enum.map(fn t -> Map.get(t, "hash") end)

      acc ++ hashes
    end)
    |> Enum.chunk_every(@eth_get_logs_range_size)
    |> Enum.reduce([], fn hashes, acc ->
      acc ++ get_receipt_logs(hashes, json_rpc_named_arguments, Helper.infinite_retries_number())
    end)
    |> filter_deposit_events(child_chain)
  end

  defp get_withdrawal_logs_from_receipts(blocks, bone_withdraw, json_rpc_named_arguments) do
    blocks
    |> Enum.reduce([], fn block, acc ->
      hashes =
        block
        |> Map.get("transactions", [])
        |> Enum.filter(fn t ->
          # filter by `withdraw(uint256 amount)` signature
          String.downcase(String.slice(Map.get(t, "input", ""), 0..9)) == @withdraw_method
        end)
        |> Enum.map(fn t -> Map.get(t, "hash") end)

      acc ++ hashes
    end)
    |> Enum.chunk_every(@eth_get_logs_range_size)
    |> Enum.reduce([], fn hashes, acc ->
      acc ++ get_receipt_logs(hashes, json_rpc_named_arguments, Helper.infinite_retries_number())
    end)
    |> filter_withdrawal_events(bone_withdraw)
  end

  defp get_op_amounts(event) do
    cond do
      event.first_topic == @token_deposited_event ->
        [amount, deposit_count] = decode_data(event.data, [{:uint, 256}, {:uint, 256}])
        {[amount], deposit_count}

      event.first_topic == @transfer_event ->
        indexed_token_id = event.fourth_topic

        if is_nil(indexed_token_id) do
          {decode_data(event.data, [{:uint, 256}]), 0}
        else
          {[quantity_to_integer(indexed_token_id)], 0}
        end

      event.first_topic == @withdraw_event ->
        [amount, _arg3, _arg4] = decode_data(event.data, [{:uint, 256}, {:uint, 256}, {:uint, 256}])
        {[amount], 0}

      true ->
        {[nil], 0}
    end
  end

  defp get_op_erc1155_data(event) do
    cond do
      event.first_topic == @transfer_single_event ->
        [id, amount] = decode_data(event.data, [{:uint, 256}, {:uint, 256}])
        {[id], [amount]}

      event.first_topic == @transfer_batch_event ->
        [ids, amounts] = decode_data(event.data, [{:array, {:uint, 256}}, {:array, {:uint, 256}}])
        {ids, amounts}

      true ->
        {[], []}
    end
  end

  # credo:disable-for-next-line /Complexity/
  defp get_op_user(event) do
    cond do
      event.first_topic == @transfer_event and event.third_topic == @empty_hash ->
        truncate_address_hash(event.second_topic)

      event.first_topic == @transfer_event and event.second_topic == @empty_hash ->
        truncate_address_hash(event.third_topic)

      event.first_topic == @withdraw_event ->
        truncate_address_hash(event.third_topic)

      Enum.member?([@transfer_single_event, @transfer_batch_event], event.first_topic) and
          event.fourth_topic == @empty_hash ->
        truncate_address_hash(event.third_topic)

      Enum.member?([@transfer_single_event, @transfer_batch_event], event.first_topic) and
          event.third_topic == @empty_hash ->
        truncate_address_hash(event.fourth_topic)

      event.first_topic == @token_deposited_event ->
        truncate_address_hash(event.fourth_topic)
    end
  end

  defp get_receipt_logs(transaction_hashes, json_rpc_named_arguments, retries) do
    reqs =
      transaction_hashes
      |> Enum.with_index()
      |> Enum.map(fn {hash, id} ->
        request(%{
          id: id,
          method: "eth_getTransactionReceipt",
          params: [hash]
        })
      end)

    error_message = &"eth_getTransactionReceipt failed. Error: #{inspect(&1)}"

    {:ok, receipts} = Helper.repeated_call(&json_rpc/2, [reqs, json_rpc_named_arguments], error_message, retries)

    receipts
    |> Enum.map(&Receipt.elixir_to_logs(&1.result))
    |> List.flatten()
    |> Logs.elixir_to_params()
  end

  defp withdrawal?(event) do
    cond do
      event.first_topic == @withdraw_event ->
        true

      event.first_topic == @transfer_event and event.third_topic == @empty_hash ->
        true

      Enum.member?([@transfer_single_event, @transfer_batch_event], event.first_topic) and
          event.fourth_topic == @empty_hash ->
        true

      true ->
        false
    end
  end

  defp prepare_operation(event, timestamps, weth) do
    event =
      event
      |> Map.put(:first_topic, Helper.log_topic_to_string(event.first_topic))
      |> Map.put(:second_topic, Helper.log_topic_to_string(event.second_topic))
      |> Map.put(:third_topic, Helper.log_topic_to_string(event.third_topic))
      |> Map.put(:fourth_topic, Helper.log_topic_to_string(event.fourth_topic))

    user = get_op_user(event)

    if user == burn_address_hash_string() do
      []
    else
      {amounts_or_ids, operation_id} = get_op_amounts(event)
      {erc1155_ids, erc1155_amounts} = get_op_erc1155_data(event)

      l2_block_number = quantity_to_integer(event.block_number)

      {operation_type, timestamp} =
        if withdrawal?(event) do
          {:withdrawal, Map.get(timestamps, l2_block_number)}
        else
          {:deposit, nil}
        end

      token_type =
        cond do
          Enum.member?([@token_deposited_event, @withdraw_event], event.first_topic) ->
            "bone"

          event.first_topic == @transfer_event and String.downcase(event.address_hash) == weth ->
            "eth"

          true ->
            "other"
        end

      Enum.map(amounts_or_ids, fn amount_or_id ->
        %{
          user: user,
          amount_or_id: amount_or_id,
          erc1155_ids: if(Enum.empty?(erc1155_ids), do: nil, else: erc1155_ids),
          erc1155_amounts: if(Enum.empty?(erc1155_amounts), do: nil, else: erc1155_amounts),
          l2_transaction_hash: event.transaction_hash,
          l2_block_number: l2_block_number,
          l1_transaction_hash: @empty_hash,
          operation_hash: calc_operation_hash(user, amount_or_id, erc1155_ids, erc1155_amounts, operation_id),
          operation_type: operation_type,
          token_type: token_type,
          timestamp: timestamp
        }
      end)
    end
  end

  defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
  end
end
