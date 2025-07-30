defmodule Indexer.Fetcher.Shibarium.L1 do
  @moduledoc """
  Fills shibarium_bridge DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC,
    only: [
      integer_to_quantity: 1,
      json_rpc: 2,
      quantity_to_integer: 1,
      request: 1
    ]

  import Explorer.Helper, only: [parse_integer: 1, decode_data: 2]

  import Indexer.Fetcher.Shibarium.Helper,
    only: [calc_operation_hash: 5, prepare_insert_items: 2, recalculate_cached_count: 0]

  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Explorer.Chain.Shibarium.Bridge
  alias Explorer.{Chain, Repo}
  alias Indexer.Fetcher.RollupL1ReorgMonitor
  alias Indexer.Helper
  alias Indexer.Transform.Addresses

  @block_check_interval_range_size 100
  @eth_get_logs_range_size 1000
  @fetcher_name :shibarium_bridge_l1
  @empty_hash "0x0000000000000000000000000000000000000000000000000000000000000000"

  # 32-byte signature of the event NewDepositBlock(address indexed owner, address indexed token, uint256 amountOrNFTId, uint256 depositBlockId)
  @new_deposit_block_event "0x1dadc8d0683c6f9824e885935c1bec6f76816730dcec148dda8cf25a7b9f797b"

  # 32-byte signature of the event LockedEther(address indexed depositor, address indexed depositReceiver, uint256 amount)
  @locked_ether_event "0x3e799b2d61372379e767ef8f04d65089179b7a6f63f9be3065806456c7309f1b"

  # 32-byte signature of the event LockedERC20(address indexed depositor, address indexed depositReceiver, address indexed rootToken, uint256 amount)
  @locked_erc20_event "0x9b217a401a5ddf7c4d474074aff9958a18d48690d77cc2151c4706aa7348b401"

  # 32-byte signature of the event LockedERC721(address indexed depositor, address indexed depositReceiver, address indexed rootToken, uint256 tokenId)
  @locked_erc721_event "0x8357472e13612a8c3d6f3e9d71fbba8a78ab77dbdcc7fcf3b7b645585f0bbbfc"

  # 32-byte signature of the event LockedERC721Batch(address indexed depositor, address indexed depositReceiver, address indexed rootToken, uint256[] tokenIds)
  @locked_erc721_batch_event "0x5345c2beb0e49c805f42bb70c4ec5c3c3d9680ce45b8f4529c028d5f3e0f7a0d"

  # 32-byte signature of the event LockedBatchERC1155(address indexed depositor, address indexed depositReceiver, address indexed rootToken, uint256[] ids, uint256[] amounts)
  @locked_batch_erc1155_event "0x5a921678b5779e4471b77219741a417a6ad6ec5d89fa5c8ce8cd7bd2d9f34186"

  # 32-byte signature of the event Withdraw(uint256 indexed exitId, address indexed user, address indexed token, uint256 amount)
  @withdraw_event "0xfeb2000dca3e617cd6f3a8bbb63014bb54a124aac6ccbf73ee7229b4cd01f120"

  # 32-byte signature of the event ExitedEther(address indexed exitor, uint256 amount)
  @exited_ether_event "0x0fc0eed41f72d3da77d0f53b9594fc7073acd15ee9d7c536819a70a67c57ef3c"

  # 32-byte signature of the event Transfer(address indexed from, address indexed to, uint256 value)
  @transfer_event "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  # 32-byte signature of the event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value)
  @transfer_single_event "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62"

  # 32-byte signature of the event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values)
  @transfer_batch_event "0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb"

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
  def handle_continue(_, state) do
    Logger.metadata(fetcher: @fetcher_name)
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :wait_for_l2, 2000)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:wait_for_l2, state) do
    if is_nil(Process.whereis(Indexer.Fetcher.Shibarium.L2)) do
      Process.send(self(), :init_with_delay, [])
    else
      Process.send_after(self(), :wait_for_l2, 2000)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:init_with_delay, _state) do
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_undefined, false} <- {:start_block_undefined, is_nil(env[:start_block])},
         _ <- RollupL1ReorgMonitor.wait_for_start(__MODULE__),
         rpc = env[:rpc],
         {:rpc_undefined, false} <- {:rpc_undefined, is_nil(rpc)},
         {:deposit_manager_address_is_valid, true} <-
           {:deposit_manager_address_is_valid, Helper.address_correct?(env[:deposit_manager_proxy])},
         {:ether_predicate_address_is_valid, true} <-
           {:ether_predicate_address_is_valid, Helper.address_correct?(env[:ether_predicate_proxy])},
         {:erc20_predicate_address_is_valid, true} <-
           {:erc20_predicate_address_is_valid, Helper.address_correct?(env[:erc20_predicate_proxy])},
         {:erc721_predicate_address_is_valid, true} <-
           {:erc721_predicate_address_is_valid,
            is_nil(env[:erc721_predicate_proxy]) or Helper.address_correct?(env[:erc721_predicate_proxy])},
         {:erc1155_predicate_address_is_valid, true} <-
           {:erc1155_predicate_address_is_valid,
            is_nil(env[:erc1155_predicate_proxy]) or Helper.address_correct?(env[:erc1155_predicate_proxy])},
         {:withdraw_manager_address_is_valid, true} <-
           {:withdraw_manager_address_is_valid, Helper.address_correct?(env[:withdraw_manager_proxy])},
         start_block = parse_integer(env[:start_block]),
         false <- is_nil(start_block),
         true <- start_block > 0,
         {last_l1_block_number, last_l1_transaction_hash} <- get_last_l1_item(),
         {:start_block_valid, true} <-
           {:start_block_valid, start_block <= last_l1_block_number || last_l1_block_number == 0},
         json_rpc_named_arguments = json_rpc_named_arguments(rpc),
         {:ok, last_l1_transaction} <-
           Helper.get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
         {:l1_transaction_not_found, false} <-
           {:l1_transaction_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_transaction)},
         {:ok, block_check_interval, latest_block} <- get_block_check_interval(json_rpc_named_arguments),
         {:start_block_valid, true} <- {:start_block_valid, start_block <= latest_block} do
      recalculate_cached_count()

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         deposit_manager_proxy: env[:deposit_manager_proxy],
         ether_predicate_proxy: env[:ether_predicate_proxy],
         erc20_predicate_proxy: env[:erc20_predicate_proxy],
         erc721_predicate_proxy: env[:erc721_predicate_proxy],
         erc1155_predicate_proxy: env[:erc1155_predicate_proxy],
         withdraw_manager_proxy: env[:withdraw_manager_proxy],
         block_check_interval: block_check_interval,
         start_block: max(start_block, last_l1_block_number),
         end_block: latest_block,
         json_rpc_named_arguments: json_rpc_named_arguments
       }}
    else
      {:start_block_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, %{}}

      {:rpc_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, %{}}

      {:deposit_manager_address_is_valid, false} ->
        Logger.error("DepositManagerProxy contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:ether_predicate_address_is_valid, false} ->
        Logger.error("EtherPredicateProxy contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:erc20_predicate_address_is_valid, false} ->
        Logger.error("ERC20PredicateProxy contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:erc721_predicate_address_is_valid, false} ->
        Logger.error("ERC721PredicateProxy contract address is invalid.")
        {:stop, :normal, %{}}

      {:erc1155_predicate_address_is_valid, false} ->
        Logger.error("ERC1155PredicateProxy contract address is invalid.")
        {:stop, :normal, %{}}

      {:withdraw_manager_address_is_valid, false} ->
        Logger.error("WithdrawManagerProxy contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:start_block_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and shibarium_bridge table.")
        {:stop, :normal, %{}}

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, latest block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        {:stop, :normal, %{}}

      {:l1_transaction_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check shibarium_bridge table."
        )

        {:stop, :normal, %{}}

      _ ->
        Logger.error("L1 Start Block is invalid or zero.")
        {:stop, :normal, %{}}
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          deposit_manager_proxy: deposit_manager_proxy,
          ether_predicate_proxy: ether_predicate_proxy,
          erc20_predicate_proxy: erc20_predicate_proxy,
          erc721_predicate_proxy: erc721_predicate_proxy,
          erc1155_predicate_proxy: erc1155_predicate_proxy,
          withdraw_manager_proxy: withdraw_manager_proxy,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    time_before = Timex.now()

    last_written_block =
      start_block..end_block
      |> Enum.chunk_every(@eth_get_logs_range_size)
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = List.first(current_chunk)
        chunk_end = List.last(current_chunk)

        if chunk_start <= chunk_end do
          Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, :L1)

          operations =
            {chunk_start, chunk_end}
            |> get_logs_all(
              deposit_manager_proxy,
              ether_predicate_proxy,
              erc20_predicate_proxy,
              erc721_predicate_proxy,
              erc1155_predicate_proxy,
              withdraw_manager_proxy,
              json_rpc_named_arguments
            )
            |> prepare_operations(json_rpc_named_arguments)

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
            "#{Enum.count(operations)} L1 operation(s)",
            :L1
          )
        end

        reorg_block = RollupReorgMonitorQueue.reorg_block_pop(__MODULE__)

        if !is_nil(reorg_block) && reorg_block > 0 do
          reorg_handle(reorg_block)
          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1

    {:ok, new_end_block} =
      Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number())

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

  @doc """
    Returns L1 RPC URL for this module.
  """
  @spec l1_rpc_url() :: binary()
  def l1_rpc_url do
    Application.get_all_env(:indexer)[__MODULE__][:rpc]
  end

  @doc """
    Determines if `Indexer.Fetcher.RollupL1ReorgMonitor` module must be up
    for this module.

    ## Returns
    - `true` if the reorg monitor must be active, `false` otherwise.
  """
  @spec requires_l1_reorg_monitor?() :: boolean()
  def requires_l1_reorg_monitor? do
    module_config = Application.get_all_env(:indexer)[__MODULE__]
    not is_nil(module_config[:start_block])
  end

  defp filter_deposit_events(events) do
    Enum.filter(events, fn event ->
      topic0 = Enum.at(event["topics"], 0)
      deposit?(topic0)
    end)
  end

  defp get_block_check_interval(json_rpc_named_arguments) do
    with {:ok, latest_block} <- Helper.get_block_number_by_tag("latest", json_rpc_named_arguments),
         first_block = max(latest_block - @block_check_interval_range_size, 1),
         {:ok, first_block_timestamp} <-
           Helper.get_block_timestamp_by_number_or_tag(first_block, json_rpc_named_arguments),
         {:ok, last_safe_block_timestamp} <-
           Helper.get_block_timestamp_by_number_or_tag(latest_block, json_rpc_named_arguments) do
      block_check_interval =
        ceil((last_safe_block_timestamp - first_block_timestamp) / (latest_block - first_block) * 1000 / 2)

      Logger.info("Block check interval is calculated as #{block_check_interval} ms.")
      {:ok, block_check_interval, latest_block}
    else
      {:error, error} ->
        {:error, "Failed to calculate block check interval due to #{inspect(error)}"}
    end
  end

  defp get_last_l1_item do
    query =
      from(sb in Bridge,
        select: {sb.l1_block_number, sb.l1_transaction_hash},
        where: not is_nil(sb.l1_block_number),
        order_by: [desc: sb.l1_block_number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  defp get_logs(from_block, to_block, address, topics, json_rpc_named_arguments, retries) do
    processed_from_block = integer_to_quantity(from_block)
    processed_to_block = integer_to_quantity(to_block)

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

    Helper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  defp get_logs_all(
         {chunk_start, chunk_end},
         deposit_manager_proxy,
         ether_predicate_proxy,
         erc20_predicate_proxy,
         erc721_predicate_proxy,
         erc1155_predicate_proxy,
         withdraw_manager_proxy,
         json_rpc_named_arguments
       ) do
    {:ok, known_tokens_result} =
      get_logs(
        chunk_start,
        chunk_end,
        [deposit_manager_proxy, ether_predicate_proxy, erc20_predicate_proxy, withdraw_manager_proxy],
        [
          [
            @new_deposit_block_event,
            @locked_ether_event,
            @locked_erc20_event,
            @locked_erc721_event,
            @locked_erc721_batch_event,
            @locked_batch_erc1155_event,
            @withdraw_event,
            @exited_ether_event
          ]
        ],
        json_rpc_named_arguments,
        Helper.infinite_retries_number()
      )

    contract_addresses =
      if is_nil(erc721_predicate_proxy) do
        [pad_address_hash(erc20_predicate_proxy)]
      else
        [pad_address_hash(erc20_predicate_proxy), pad_address_hash(erc721_predicate_proxy)]
      end

    {:ok, unknown_erc20_erc721_tokens_result} =
      get_logs(
        chunk_start,
        chunk_end,
        nil,
        [
          @transfer_event,
          contract_addresses
        ],
        json_rpc_named_arguments,
        Helper.infinite_retries_number()
      )

    {:ok, unknown_erc1155_tokens_result} =
      if is_nil(erc1155_predicate_proxy) do
        {:ok, []}
      else
        get_logs(
          chunk_start,
          chunk_end,
          nil,
          [
            [@transfer_single_event, @transfer_batch_event],
            nil,
            pad_address_hash(erc1155_predicate_proxy)
          ],
          json_rpc_named_arguments,
          Helper.infinite_retries_number()
        )
      end

    known_tokens_result ++ unknown_erc20_erc721_tokens_result ++ unknown_erc1155_tokens_result
  end

  defp get_op_user(topic0, event) do
    cond do
      Enum.member?([@new_deposit_block_event, @exited_ether_event], topic0) ->
        truncate_address_hash(Enum.at(event["topics"], 1))

      Enum.member?(
        [
          @locked_ether_event,
          @locked_erc20_event,
          @locked_erc721_event,
          @locked_erc721_batch_event,
          @locked_batch_erc1155_event,
          @withdraw_event,
          @transfer_event
        ],
        topic0
      ) ->
        truncate_address_hash(Enum.at(event["topics"], 2))

      Enum.member?([@transfer_single_event, @transfer_batch_event], topic0) ->
        truncate_address_hash(Enum.at(event["topics"], 3))
    end
  end

  defp get_op_amounts(topic0, event) do
    cond do
      topic0 == @new_deposit_block_event ->
        [amount_or_nft_id, deposit_block_id] = decode_data(event["data"], [{:uint, 256}, {:uint, 256}])
        {[amount_or_nft_id], deposit_block_id}

      topic0 == @transfer_event ->
        indexed_token_id = Enum.at(event["topics"], 3)

        if is_nil(indexed_token_id) do
          {decode_data(event["data"], [{:uint, 256}]), 0}
        else
          {[quantity_to_integer(indexed_token_id)], 0}
        end

      Enum.member?(
        [
          @locked_ether_event,
          @locked_erc20_event,
          @locked_erc721_event,
          @withdraw_event,
          @exited_ether_event
        ],
        topic0
      ) ->
        {decode_data(event["data"], [{:uint, 256}]), 0}

      topic0 == @locked_erc721_batch_event ->
        [ids] = decode_data(event["data"], [{:array, {:uint, 256}}])
        {ids, 0}

      true ->
        {[nil], 0}
    end
  end

  defp get_op_erc1155_data(topic0, event) do
    cond do
      Enum.member?([@locked_batch_erc1155_event, @transfer_batch_event], topic0) ->
        [ids, amounts] = decode_data(event["data"], [{:array, {:uint, 256}}, {:array, {:uint, 256}}])
        {ids, amounts}

      Enum.member?([@transfer_single_event], topic0) ->
        [id, amount] = decode_data(event["data"], [{:uint, 256}, {:uint, 256}])
        {[id], [amount]}

      true ->
        {[], []}
    end
  end

  defp deposit?(topic0) do
    Enum.member?(
      [
        @new_deposit_block_event,
        @locked_ether_event,
        @locked_erc20_event,
        @locked_erc721_event,
        @locked_erc721_batch_event,
        @locked_batch_erc1155_event
      ],
      topic0
    )
  end

  defp json_rpc_named_arguments(rpc_url) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.Tesla,
        urls: [rpc_url],
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          pool: :ethereum_jsonrpc
        ]
      ]
    ]
  end

  defp prepare_operations(events, json_rpc_named_arguments) do
    timestamps =
      events
      |> filter_deposit_events()
      |> Helper.get_blocks_by_events(json_rpc_named_arguments, Helper.infinite_retries_number())
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

      l1_block_number = quantity_to_integer(event["blockNumber"])

      {operation_type, timestamp} =
        if deposit?(topic0) do
          {:deposit, Map.get(timestamps, l1_block_number)}
        else
          {:withdrawal, nil}
        end

      token_type =
        cond do
          Enum.member?([@new_deposit_block_event, @withdraw_event], topic0) ->
            "bone"

          Enum.member?([@locked_ether_event, @exited_ether_event], topic0) ->
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
          l1_transaction_hash: event["transactionHash"],
          l1_block_number: l1_block_number,
          l2_transaction_hash: @empty_hash,
          operation_hash: calc_operation_hash(user, amount_or_id, erc1155_ids, erc1155_amounts, operation_id),
          operation_type: operation_type,
          token_type: token_type,
          timestamp: timestamp
        }
      end)
    end)
    |> List.flatten()
  end

  defp pad_address_hash(address) do
    "0x" <>
      (address
       |> String.trim_leading("0x")
       |> String.pad_leading(64, "0"))
  end

  defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
  end

  defp reorg_handle(reorg_block) do
    {deleted_count, _} =
      Repo.delete_all(from(sb in Bridge, where: sb.l1_block_number >= ^reorg_block and is_nil(sb.l2_transaction_hash)))

    {updated_count1, _} =
      Repo.update_all(
        from(sb in Bridge,
          where:
            sb.l1_block_number >= ^reorg_block and not is_nil(sb.l2_transaction_hash) and
              sb.operation_type == :deposit
        ),
        set: [timestamp: nil]
      )

    {updated_count2, _} =
      Repo.update_all(
        from(sb in Bridge, where: sb.l1_block_number >= ^reorg_block and not is_nil(sb.l2_transaction_hash)),
        set: [l1_transaction_hash: nil, l1_block_number: nil]
      )

    updated_count = max(updated_count1, updated_count2)

    if deleted_count > 0 or updated_count > 0 do
      recalculate_cached_count()

      Logger.warning(
        "As L1 reorg was detected, some rows with l1_block_number >= #{reorg_block} were affected (removed or updated) in the shibarium_bridge table. Number of removed rows: #{deleted_count}. Number of updated rows: >= #{updated_count}."
      )
    end
  end
end
