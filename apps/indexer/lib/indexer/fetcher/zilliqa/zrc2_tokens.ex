defmodule Indexer.Fetcher.Zilliqa.Zrc2Tokens do
  @moduledoc """
  Fills `zrc2_token_transfers` (or `token_transfers` along with `tokens` DB tables) and `zrc2_token_adapters` table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  alias Explorer.Repo
  alias Explorer.Chain.{Block, Data, Hash, Log, TokenTransfer, Transaction}
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Zilliqa.Zrc2.TokenAdapter

  @fetcher_name :zilliqa_zrc2_tokens
  @counter_type "zilliqa_zrc2_tokens_fetcher_max_block_number"

  @zrc2_transfer_success_event "0xa5901fdb53ef45260c18811f35461e0eda2b6133d807dabbfb65314dd4fc2fac"
  @zrc2_transfer_from_success_event "0x96acecb2152edcc0681aa27d354d55d64192e86489ff8d5d903d63ef266755a1"
  @zrc2_minted_event "0x845020906442ad0651b44a75d9767153912bfa586416784cf8ead41b37b1dbf5"
  @zrc2_burnt_event "0x92b328e20a23b6dc6c50345c8a05b555446cbde2e9e1e2ee91dab47bd5204d07"

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
    {:ok, %{}, {:continue, nil}}
  end

  @impl GenServer
  def handle_continue(_, state) do
    Logger.metadata(fetcher: @fetcher_name)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    block_number_to_analyze =
      case LastFetchedCounter.get(@counter_type, nullable: true) do
        nil -> last_known_block_number()
        block_number -> Decimal.to_integer(block_number)
      end

    if is_nil(block_number_to_analyze) do
      Logger.warning("There are no known consensus blocks in the database, so #{__MODULE__} won't start.")
      {:stop, :normal, state}
    else
      Process.send(self(), :continue, [])
      {:noreply, %{block_number_to_analyze: block_number_to_analyze}}
    end
  end

  @impl GenServer
  def handle_info(:continue, %{block_number_to_analyze: block_number_to_analyze}) do
    if block_number_to_analyze > 0 do
      logs = read_block_logs(block_number_to_analyze)
      transactions = read_transfer_transactions(logs)

      # fetch_zrc2_token_transfers_and_adapters(logs, transactions)
      # move_zrc2_token_transfers_to_token_transfers()

      LastFetchedCounter.upsert(%{
        counter_type: @counter_type,
        value: block_number_to_analyze - 1
      })

      Process.send(self(), :continue, [])
    else
      # move_zrc2_token_transfers_to_token_transfers()
      Process.send_after(self(), :continue, :timer.seconds(10))
    end

    {:noreply, %{block_number_to_analyze: max(block_number_to_analyze - 1, 0)}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # def fetch_zrc2_token_transfers_and_adapters(logs, transactions)

  @spec read_block_logs(non_neg_integer()) :: [
          %{
            first_topic: Hash.t(),
            data: Data.t(),
            address_hash: Hash.t(),
            transaction_hash: Hash.t(),
            index: non_neg_integer(),
            block_hash: Hash.t(),
            adapter_address_hash: Hash.t() | nil
          }
        ]
  defp read_block_logs(block_number) do
    transfer_events = [
      @zrc2_transfer_success_event,
      @zrc2_transfer_from_success_event,
      @zrc2_minted_event,
      @zrc2_burnt_event,
      TokenTransfer.constant()
    ]

    Repo.all(
      from(
        l in Log,
        inner_join: b in Block,
        on: b.hash == l.block_hash and b.consensus == true,
        left_join: a in TokenAdapter,
        on: a.zrc2_address_hash == l.address_hash,
        where: l.block_number == ^block_number and l.first_topic in ^transfer_events,
        select: %{
          first_topic: l.first_topic,
          data: l.data,
          address_hash: l.address_hash,
          transaction_hash: l.transaction_hash,
          index: l.index,
          block_hash: l.block_hash,
          adapter_address_hash: a.adapter_address_hash
        }
      ),
      timeout: :infinity
    )
  end

  @spec read_transfer_transactions([%{first_topic: Hash.t(), transaction_hash: Hash.t(), adapter_address_hash: Hash.t() | nil}]) :: [%{hash: Hash.t(), input: Data.t(), to_address_hash: Hash.t()}]
  defp read_transfer_transactions(logs) do
    transaction_hashes =
      logs
      |> Enum.filter(&(Hash.to_string(&1.first_topic) == @zrc2_transfer_success_event and is_nil(&1.adapter_address_hash)))
      |> Enum.map(& &1.transaction_hash)

    Repo.all(
      from(
        t in Transaction,
        where: t.hash in ^transaction_hashes,
        select: %{
          hash: t.hash,
          input: t.input,
          to_address_hash: t.to_address_hash
        }
      ),
      timeout: :infinity
    )
  end

  @spec last_known_block_number() :: non_neg_integer() | nil
  defp last_known_block_number do
    Repo.aggregate(Block.consensus_blocks_query(), :max, :number)
  end

  # defp find_and_save_withdrawals(
  #        scan_db,
  #        message_passer,
  #        block_start,
  #        block_end,
  #        json_rpc_named_arguments
  #      ) do
  #   message_passed_event = OptimismWithdrawal.message_passed_event()

  #   withdrawals =
  #     if scan_db do
  #       query =
  #         from(log in Log,
  #           select: {log.second_topic, log.data, log.transaction_hash, log.block_number},
  #           where:
  #             log.first_topic == ^message_passed_event and log.address_hash == ^message_passer and
  #               log.block_number >= ^block_start and log.block_number <= ^block_end
  #         )

  #       query
  #       |> Repo.all(timeout: :infinity)
  #       |> Enum.map(fn {second_topic, data, l2_transaction_hash, l2_block_number} ->
  #         event_to_withdrawal(second_topic, data, l2_transaction_hash, l2_block_number)
  #       end)
  #     else
  #       {:ok, result} =
  #         Helper.get_logs(
  #           block_start,
  #           block_end,
  #           message_passer,
  #           [message_passed_event],
  #           json_rpc_named_arguments,
  #           0,
  #           3
  #         )

  #       Enum.map(result, fn event ->
  #         event_to_withdrawal(
  #           Enum.at(event["topics"], 1),
  #           event["data"],
  #           event["transactionHash"],
  #           event["blockNumber"]
  #         )
  #       end)
  #     end

  #   {:ok, _} =
  #     Chain.import(%{
  #       optimism_withdrawals: %{params: withdrawals},
  #       timeout: :infinity
  #     })

  #   Enum.count(withdrawals)
  # end

  # defp fill_block_range(
  #        l2_block_start,
  #        l2_block_end,
  #        message_passer,
  #        json_rpc_named_arguments,
  #        eth_get_logs_range_size,
  #        scan_db
  #      ) do
  #   chunks_number =
  #     if scan_db do
  #       1
  #     else
  #       ceil((l2_block_end - l2_block_start + 1) / eth_get_logs_range_size)
  #     end

  #   chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

  #   Enum.reduce(chunk_range, 0, fn current_chunk, withdrawals_count_acc ->
  #     chunk_start = l2_block_start + eth_get_logs_range_size * current_chunk

  #     chunk_end =
  #       if scan_db do
  #         l2_block_end
  #       else
  #         min(chunk_start + eth_get_logs_range_size - 1, l2_block_end)
  #       end

  #     Helper.log_blocks_chunk_handling(chunk_start, chunk_end, l2_block_start, l2_block_end, nil, :L2)

  #     withdrawals_count =
  #       find_and_save_withdrawals(
  #         scan_db,
  #         message_passer,
  #         chunk_start,
  #         chunk_end,
  #         json_rpc_named_arguments
  #       )

  #     Helper.log_blocks_chunk_handling(
  #       chunk_start,
  #       chunk_end,
  #       l2_block_start,
  #       l2_block_end,
  #       "#{withdrawals_count} MessagePassed event(s)",
  #       :L2
  #     )

  #     withdrawals_count_acc + withdrawals_count
  #   end)
  # end

  # defp fill_block_range(start_block, end_block, message_passer, json_rpc_named_arguments, eth_get_logs_range_size) do
  #   if start_block <= end_block do
  #     fill_block_range(start_block, end_block, message_passer, json_rpc_named_arguments, eth_get_logs_range_size, true)
  #     fill_msg_nonce_gaps(start_block, message_passer, json_rpc_named_arguments, eth_get_logs_range_size, false)
  #     {last_l2_block_number, _, _} = get_last_l2_item()

  #     fill_block_range(
  #       max(start_block, last_l2_block_number),
  #       end_block,
  #       message_passer,
  #       json_rpc_named_arguments,
  #       eth_get_logs_range_size,
  #       false
  #     )

  #     Optimism.set_last_block_hash_by_number(end_block, @counter_type, json_rpc_named_arguments)
  #   end
  # end

  # defp fill_msg_nonce_gaps(
  #        start_block_l2,
  #        message_passer,
  #        json_rpc_named_arguments,
  #        eth_get_logs_range_size,
  #        scan_db \\ true
  #      ) do
  #   nonce_min = Repo.aggregate(OptimismWithdrawal, :min, :msg_nonce)
  #   nonce_max = Repo.aggregate(OptimismWithdrawal, :max, :msg_nonce)

  #   with true <- !is_nil(nonce_min) and !is_nil(nonce_max),
  #        starts = msg_nonce_gap_starts(nonce_max),
  #        ends = msg_nonce_gap_ends(nonce_min),
  #        min_block_l2 = l2_block_number_by_msg_nonce(nonce_min),
  #        {new_starts, new_ends} =
  #          if(start_block_l2 < min_block_l2,
  #            do: {[start_block_l2 | starts], [min_block_l2 | ends]},
  #            else: {starts, ends}
  #          ),
  #        true <- Enum.count(new_starts) == Enum.count(new_ends) do
  #     new_starts
  #     |> Enum.zip(new_ends)
  #     |> Enum.each(fn {l2_block_start, l2_block_end} ->
  #       withdrawals_count =
  #         fill_block_range(
  #           l2_block_start,
  #           l2_block_end,
  #           message_passer,
  #           json_rpc_named_arguments,
  #           eth_get_logs_range_size,
  #           scan_db
  #         )

  #       if withdrawals_count > 0 do
  #         log_fill_msg_nonce_gaps(scan_db, l2_block_start, l2_block_end, withdrawals_count)
  #       end
  #     end)

  #     if scan_db do
  #       fill_msg_nonce_gaps(start_block_l2, message_passer, json_rpc_named_arguments, eth_get_logs_range_size, false)
  #     end
  #   end
  # end

  # # Determines the last saved L2 block number, the last saved transaction hash, and the transaction info for withdrawals.
  # #
  # # Utilized to start fetching from a correct block number after reorg has occurred.
  # #
  # # ## Parameters
  # # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  # #                               Used to get transaction info by its hash from the RPC node.
  # #                               Can be `nil` if the transaction info is not needed.
  # #
  # # ## Returns
  # # - A tuple `{last_block_number, last_transaction_hash, last_transaction}` where
  # #   `last_block_number` is the last block number found in the corresponding table (0 if not found),
  # #   `last_transaction_hash` is the last transaction hash found in the corresponding table (nil if not found),
  # #   `last_transaction` is the transaction info got from the RPC (nil if not found or not needed).
  # # - A tuple `{:error, message}` in case the `eth_getTransactionByHash` RPC request failed.
  # @spec get_last_l2_item(EthereumJSONRPC.json_rpc_named_arguments() | nil) ::
  #         {non_neg_integer(), binary() | nil, map() | nil} | {:error, any()}
  # defp get_last_l2_item(json_rpc_named_arguments \\ nil) do
  #   Optimism.get_last_item(
  #     :L2,
  #     &OptimismWithdrawal.last_withdrawal_l2_block_number_query/0,
  #     &OptimismWithdrawal.remove_withdrawals_query/1,
  #     json_rpc_named_arguments,
  #     @counter_type
  #   )
  # end

  # defp log_fill_msg_nonce_gaps(scan_db, l2_block_start, l2_block_end, withdrawals_count) do
  #   find_place = if scan_db, do: "in DB", else: "through RPC"

  #   Logger.info(
  #     "Filled gaps between L2 blocks #{l2_block_start} and #{l2_block_end}. #{withdrawals_count} event(s) were found #{find_place} and written to op_withdrawals table."
  #   )
  # end

  # defp l2_block_number_by_msg_nonce(nonce) do
  #   Repo.one(from(w in OptimismWithdrawal, select: w.l2_block_number, where: w.msg_nonce == ^nonce))
  # end
end
