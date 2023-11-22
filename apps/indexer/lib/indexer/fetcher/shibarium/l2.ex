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
      fetch_block_number_by_tag: 2,
      integer_to_quantity: 1,
      json_rpc: 2,
      quantity_to_integer: 1,
      request: 1
    ]

  import Explorer.Helper, only: [decode_data: 2, parse_integer: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Shibarium.Bridge
  alias Indexer.Helper

  @burn_address "0x0000000000000000000000000000000000000000"
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

  # 32-byte signature of the event LogFeeTransfer(address indexed, address indexed, address indexed, uint256, uint256, uint256, uint256, uint256)
  @log_fee_transfer_event "0x4dfe1bbbcf077ddc3e01291eea2d5c70c2b422b415d95645b9adcfd678cb1d63"

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
           {:child_chain_address_is_valid, Helper.is_address_correct?(env[:child_chain])},
         {:weth_address_is_valid, true} <- {:weth_address_is_valid, Helper.is_address_correct?(env[:weth])},
         {:bone_withdraw_address_is_valid, true} <-
           {:bone_withdraw_address_is_valid, Helper.is_address_correct?(env[:bone_withdraw])},
         start_block = parse_integer(env[:start_block]),
         false <- is_nil(start_block),
         true <- start_block > 0,
         {last_l2_block_number, last_l2_transaction_hash} <- get_last_l2_item(),
         {:ok, latest_block} = get_block_number_by_tag("latest", json_rpc_named_arguments),
         {:start_block_valid, true} <-
           {:start_block_valid,
            (start_block <= last_l2_block_number || last_l2_block_number == 0) && start_block <= latest_block},
         {:ok, last_l2_tx} <- get_transaction_by_hash(last_l2_transaction_hash, json_rpc_named_arguments),
         {:l2_tx_not_found, false} <- {:l2_tx_not_found, !is_nil(last_l2_transaction_hash) && is_nil(last_l2_tx)} do
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

      {:l2_tx_not_found, true} ->
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

      log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, "L2")

      operations =
        {chunk_start, chunk_end}
        |> get_logs_all(child_chain, weth, bone_withdraw, json_rpc_named_arguments)
        |> prepare_operations(weth)

      {:ok, _} =
        Chain.import(%{
          shibarium_bridge_operations: %{params: prepare_insert_items(operations)},
          timeout: :infinity
        })

      log_blocks_chunk_handling(
        chunk_start,
        chunk_end,
        start_block,
        end_block,
        "#{Enum.count(operations)} L2 operation(s)",
        "L2"
      )
    end)

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def reorg_handle(reorg_block) do
    {deleted_count, _} =
      Repo.delete_all(from(sb in Bridge, where: sb.l2_block_number >= ^reorg_block and is_nil(sb.l1_transaction_hash)))

    {updated_count1, _} =
      Repo.update_all(
        from(sb in Bridge,
          where:
            sb.l2_block_number >= ^reorg_block and not is_nil(sb.l1_transaction_hash) and
              sb.operation_type == "withdrawal"
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
      Logger.warning(
        "As L2 reorg was detected, some rows with l2_block_number >= #{reorg_block} were affected (removed or updated) in the shibarium_bridge table. Number of removed rows: #{deleted_count}. Number of updated rows: >= #{updated_count}."
      )
    end
  end

  defp bind_existing_operation_in_db(op) do
    query =
      from(sb in Bridge,
        where:
          sb.operation_hash == ^op.operation_hash and sb.operation_type == ^op.operation_type and
            sb.l1_transaction_hash != ^@empty_hash and sb.l2_transaction_hash == ^@empty_hash,
        order_by: [asc: sb.l1_block_number],
        limit: 1
      )

    {updated_count, _} =
      Repo.update_all(
        from(b in Bridge,
          join: s in subquery(query),
          on:
            b.operation_hash == s.operation_hash and b.l1_transaction_hash == s.l1_transaction_hash and
              b.l2_transaction_hash == s.l2_transaction_hash
        ),
        set:
          [l2_transaction_hash: op.l2_transaction_hash, l2_block_number: op.l2_block_number] ++
            if(op.operation_type == "withdrawal", do: [timestamp: op.timestamp], else: [])
      )

    updated_count
  end

  defp calc_operation_hash(user, amount_or_id, erc1155_ids, erc1155_amounts, operation_id) do
    user_binary =
      user
      |> String.trim_leading("0x")
      |> Base.decode16!(case: :mixed)

    amount_or_id =
      if is_nil(amount_or_id) and not Enum.empty?(erc1155_ids) do
        0
      else
        amount_or_id
      end

    operation_encoded =
      ABI.encode("(address,uint256,uint256[],uint256[],uint256)", [
        {
          user_binary,
          amount_or_id,
          erc1155_ids,
          erc1155_amounts,
          operation_id
        }
      ])

    "0x" <>
      (operation_encoded
       |> ExKeccak.hash_256()
       |> Base.encode16(case: :lower))
  end

  defp get_block_number_by_tag(tag, json_rpc_named_arguments, retries \\ 3) do
    error_message = &"Cannot fetch #{tag} block number. Error: #{inspect(&1)}"
    repeated_call(&fetch_block_number_by_tag/2, [tag, json_rpc_named_arguments], error_message, retries)
  end

  defp get_blocks_by_range(chunk_start, chunk_end, json_rpc_named_arguments, retries) do
    request =
      chunk_start..chunk_end
      |> Stream.map(fn block_number -> %{number: block_number} end)
      |> Stream.with_index()
      |> Enum.into(%{}, fn {params, id} -> {id, params} end)
      |> Blocks.requests(&ByNumber.request(&1))

    error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

    case repeated_call(&json_rpc/2, [request, json_rpc_named_arguments], error_message, retries) do
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

  defp get_logs_all({chunk_start, chunk_end}, child_chain, weth, bone_withdraw, json_rpc_named_arguments) do
    {:ok, known_tokens_result} =
      get_logs(
        chunk_start,
        chunk_end,
        [
          weth,
          bone_withdraw
        ],
        [
          [
            @log_fee_transfer_event,
            @transfer_event,
            @withdraw_event
          ]
        ],
        json_rpc_named_arguments
      )

    {tokens_deposit_result, blocks} =
      get_deposit_logs_from_receipts(chunk_start, chunk_end, child_chain, json_rpc_named_arguments)

    {:ok, unknown_erc20_erc721_tokens_withdraw_result} =
      get_logs(
        chunk_start,
        chunk_end,
        nil,
        [
          @transfer_event,
          nil,
          @empty_hash
        ],
        json_rpc_named_arguments
      )

    {:ok, unknown_erc1155_tokens_withdraw_result} =
      get_logs(
        chunk_start,
        chunk_end,
        nil,
        [
          [@transfer_single_event, @transfer_batch_event],
          nil,
          nil,
          @empty_hash
        ],
        json_rpc_named_arguments
      )

    # filter these Transfer* events by having LogFeeTransfer event (emitted by BoneWithdraw contract) in the same transaction
    tokens_withdraw_result =
      Enum.filter(unknown_erc20_erc721_tokens_withdraw_result ++ unknown_erc1155_tokens_withdraw_result, fn event ->
        Enum.any?(known_tokens_result, fn e ->
          Enum.at(e["topics"], 0) == @log_fee_transfer_event and String.downcase(e["address"]) == bone_withdraw and
            e["transactionHash"] == event["transactionHash"]
        end)
      end)

    # remove LogFeeTransfer event (and excess Transfer events) from the list
    known_tokens_final_result =
      Enum.filter(known_tokens_result, fn event ->
        Enum.at(event["topics"], 0) != @log_fee_transfer_event and
          (Enum.at(event["topics"], 0) != @transfer_event or Enum.at(event["topics"], 1) == @empty_hash or
             Enum.at(event["topics"], 2) == @empty_hash)
      end)

    {known_tokens_final_result ++ tokens_deposit_result ++ tokens_withdraw_result, blocks}
  end

  defp get_deposit_logs_from_receipts(chunk_start, chunk_end, child_chain, json_rpc_named_arguments) do
    blocks = get_blocks_by_range(chunk_start, chunk_end, json_rpc_named_arguments, 100_000_000)

    logs =
      blocks
      |> Enum.reduce([], fn block, acc ->
        hashes =
          block
          |> Map.get("transactions", [])
          |> Enum.filter(fn t -> Map.get(t, "from") == @burn_address end)
          |> Enum.map(fn t -> Map.get(t, "hash") end)

        acc ++ hashes
      end)
      |> Enum.chunk_every(@eth_get_logs_range_size)
      |> Enum.reduce([], fn hashes, acc ->
        acc ++ get_receipt_logs(hashes, json_rpc_named_arguments, 100_000_000)
      end)
      |> Enum.filter(fn event ->
        address = String.downcase(event["address"])
        topic0 = Enum.at(event["topics"], 0)
        topic1 = Enum.at(event["topics"], 1)
        topic2 = Enum.at(event["topics"], 2)

        (topic0 == @token_deposited_event and address == child_chain) or
          (topic0 == @transfer_event and topic1 == @empty_hash) or
          (Enum.member?([@transfer_single_event, @transfer_batch_event], topic0) and topic2 == @empty_hash)
      end)

    {logs, blocks}
  end

  defp get_logs(from_block, to_block, address, topics, json_rpc_named_arguments, retries \\ 100_000_000) do
    processed_from_block = if is_integer(from_block), do: integer_to_quantity(from_block), else: from_block
    processed_to_block = if is_integer(to_block), do: integer_to_quantity(to_block), else: to_block

    req =
      request(%{
        id: 0,
        method: "eth_getLogs",
        params: [
          %{
            :fromBlock => processed_from_block,
            :toBlock => processed_to_block,
            :address => address,
            :topics => topics
          }
        ]
      })

    error_message = &"Cannot fetch logs for the block range #{from_block}..#{to_block}. Error: #{inspect(&1)}"

    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  defp get_op_amounts(topic0, event) do
    cond do
      topic0 == @token_deposited_event ->
        [amount, deposit_count] = decode_data(event["data"], [{:uint, 256}, {:uint, 256}])
        {[amount], deposit_count}

      topic0 == @transfer_event ->
        indexed_token_id = Enum.at(event["topics"], 3)

        if is_nil(indexed_token_id) do
          {decode_data(event["data"], [{:uint, 256}]), 0}
        else
          {[quantity_to_integer(indexed_token_id)], 0}
        end

      topic0 == @withdraw_event ->
        [amount, _arg3, _arg4] = decode_data(event["data"], [{:uint, 256}, {:uint, 256}, {:uint, 256}])
        {[amount], 0}

      true ->
        {[nil], 0}
    end
  end

  defp get_op_erc1155_data(topic0, event) do
    cond do
      Enum.member?([@transfer_single_event], topic0) ->
        [id, amount] = decode_data(event["data"], [{:uint, 256}, {:uint, 256}])
        {[id], [amount]}

      Enum.member?([@transfer_batch_event], topic0) ->
        [ids, amounts] = decode_data(event["data"], [{:array, {:uint, 256}}, {:array, {:uint, 256}}])
        {ids, amounts}

      true ->
        {[], []}
    end
  end

  # credo:disable-for-next-line /Complexity/
  defp get_op_user(topic0, event) do
    cond do
      topic0 == @transfer_event and Enum.at(event["topics"], 2) == @empty_hash ->
        truncate_address_hash(Enum.at(event["topics"], 1))

      topic0 == @transfer_event and Enum.at(event["topics"], 1) == @empty_hash ->
        truncate_address_hash(Enum.at(event["topics"], 2))

      topic0 == @withdraw_event ->
        truncate_address_hash(Enum.at(event["topics"], 2))

      Enum.member?([@transfer_single_event, @transfer_batch_event], topic0) and
          Enum.at(event["topics"], 3) == @empty_hash ->
        truncate_address_hash(Enum.at(event["topics"], 2))

      Enum.member?([@transfer_single_event, @transfer_batch_event], topic0) and
          Enum.at(event["topics"], 2) == @empty_hash ->
        truncate_address_hash(Enum.at(event["topics"], 3))

      topic0 == @token_deposited_event ->
        truncate_address_hash(Enum.at(event["topics"], 3))
    end
  end

  defp get_receipt_logs(tx_hashes, json_rpc_named_arguments, retries) do
    reqs =
      tx_hashes
      |> Enum.with_index()
      |> Enum.map(fn {hash, id} ->
        request(%{
          id: id,
          method: "eth_getTransactionReceipt",
          params: [hash]
        })
      end)

    error_message = &"eth_getTransactionReceipt failed. Error: #{inspect(&1)}"

    {:ok, receipts} = repeated_call(&json_rpc/2, [reqs, json_rpc_named_arguments], error_message, retries)

    receipts
    |> Enum.map(fn receipt -> Map.get(receipt.result, "logs") end)
    |> List.flatten()
  end

  defp get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left \\ 3)

  defp get_transaction_by_hash(hash, _json_rpc_named_arguments, _retries_left) when is_nil(hash), do: {:ok, nil}

  defp get_transaction_by_hash(hash, json_rpc_named_arguments, retries) do
    req =
      request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    error_message = &"eth_getTransactionByHash failed. Error: #{inspect(&1)}"

    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  defp is_withdrawal(event) do
    topic0 = Enum.at(event["topics"], 0)
    topic2 = Enum.at(event["topics"], 2)
    topic3 = Enum.at(event["topics"], 3)

    cond do
      topic0 == @withdraw_event -> true
      topic0 == @transfer_event and topic2 == @empty_hash -> true
      Enum.member?([@transfer_single_event, @transfer_batch_event], topic0) and topic3 == @empty_hash -> true
      true -> false
    end
  end

  defp log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, items_count, layer) do
    is_start = is_nil(items_count)

    {type, found} =
      if is_start do
        {"Start", ""}
      else
        {"Finish", " Found #{items_count}."}
      end

    target_range =
      if chunk_start != start_block or chunk_end != end_block do
        progress =
          if is_start do
            ""
          else
            percentage =
              (chunk_end - start_block + 1)
              |> Decimal.div(end_block - start_block + 1)
              |> Decimal.mult(100)
              |> Decimal.round(2)
              |> Decimal.to_string()

            " Progress: #{percentage}%"
          end

        " Target range: #{start_block}..#{end_block}.#{progress}"
      else
        ""
      end

    if chunk_start == chunk_end do
      Logger.info("#{type} handling #{layer} block ##{chunk_start}.#{found}#{target_range}")
    else
      Logger.info("#{type} handling #{layer} block range #{chunk_start}..#{chunk_end}.#{found}#{target_range}")
    end
  end

  defp prepare_insert_items(operations) do
    operations
    |> Enum.reduce([], fn op, acc ->
      if bind_existing_operation_in_db(op) == 0 do
        [op | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn item, acc ->
      Map.put(acc, {item.operation_hash, item.l1_transaction_hash, item.l2_transaction_hash}, item)
    end)
    |> Map.values()
  end

  defp prepare_operations({events, blocks}, weth) do
    timestamps =
      blocks
      |> Enum.reduce(%{}, fn block, acc ->
        block_number = quantity_to_integer(Map.get(block, "number"))
        {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
        Map.put(acc, block_number, timestamp)
      end)

    events
    |> Enum.map(fn event ->
      topic0 = Enum.at(event["topics"], 0)

      user = get_op_user(topic0, event)
      {amounts_or_ids, operation_id} = get_op_amounts(topic0, event)
      {erc1155_ids, erc1155_amounts} = get_op_erc1155_data(topic0, event)

      l2_block_number = quantity_to_integer(event["blockNumber"])

      {operation_type, timestamp} =
        if is_withdrawal(event) do
          {"withdrawal", Map.get(timestamps, l2_block_number)}
        else
          {"deposit", nil}
        end

      token_type =
        cond do
          Enum.member?([@token_deposited_event, @withdraw_event], topic0) ->
            "bone"

          Enum.member?([@transfer_event], topic0) and String.downcase(event["address"]) == weth ->
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
          l2_transaction_hash: event["transactionHash"],
          l2_block_number: l2_block_number,
          l1_transaction_hash: @empty_hash,
          operation_hash: calc_operation_hash(user, amount_or_id, erc1155_ids, erc1155_amounts, operation_id),
          operation_type: operation_type,
          token_type: token_type,
          timestamp: timestamp
        }
      end)
    end)
    |> List.flatten()
  end

  defp repeated_call(func, args, error_message, retries_left) do
    case apply(func, args) do
      {:ok, _} = res ->
        res

      {:error, message} = err ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          Logger.error(error_message.(message))
          err
        else
          Logger.error("#{error_message.(message)} Retrying...")
          :timer.sleep(3000)
          repeated_call(func, args, error_message, retries_left)
        end
    end
  end

  defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
  end
end
