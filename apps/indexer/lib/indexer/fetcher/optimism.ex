defmodule Indexer.Fetcher.Optimism do
  @moduledoc """
  Contains common functions for Optimism* fetchers.
  """

  require Logger

  import EthereumJSONRPC,
    only: [fetch_block_number_by_tag: 2, json_rpc: 2, integer_to_quantity: 1, quantity_to_integer: 1, request: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Indexer.{BoundQueue, Helpers}

  @block_check_interval_range_size 100
  @eth_get_logs_range_size 1000

  def get_block_number_by_tag(tag, json_rpc_named_arguments, retries_left \\ 3) do
    case fetch_block_number_by_tag(tag, json_rpc_named_arguments) do
      {:ok, block_number} ->
        {:ok, block_number}

      {:error, message} ->
        retries_left = retries_left - 1

        error_message = "Cannot fetch #{tag} block number. Error: #{inspect(message)}"

        if retries_left <= 0 do
          Logger.error(error_message)
          {:error, message}
        else
          Logger.error("#{error_message} Retrying...")
          :timer.sleep(3000)
          get_block_number_by_tag(tag, json_rpc_named_arguments, retries_left)
        end
    end
  end

  def get_block_timestamp_by_number(number, json_rpc_named_arguments, retries_left \\ 3) do
    result =
      %{id: 0, number: number}
      |> ByNumber.request(false)
      |> json_rpc(json_rpc_named_arguments)

    return =
      with {:ok, block} <- result,
           false <- is_nil(block),
           timestamp <- Map.get(block, "timestamp"),
           false <- is_nil(timestamp) do
        {:ok, quantity_to_integer(timestamp)}
      else
        {:error, message} ->
          {:error, message}

        true ->
          {:error, "RPC returned nil."}
      end

    case return do
      {:ok, timestamp} ->
        {:ok, timestamp}

      {:error, message} ->
        retries_left = retries_left - 1

        error_message = "Cannot fetch block ##{number} or its timestamp. Error: #{inspect(message)}"

        if retries_left <= 0 do
          Logger.error(error_message)
          {:error, message}
        else
          Logger.error("#{error_message} Retrying...")
          :timer.sleep(3000)
          get_block_timestamp_by_number(number, json_rpc_named_arguments, retries_left)
        end
    end
  end

  def get_block_timestamps_by_numbers(numbers, json_rpc_named_arguments, retries_left \\ 3) do
    id_to_params =
      numbers
      |> Stream.map(fn number -> %{number: number} end)
      |> Stream.with_index()
      |> Enum.into(%{}, fn {params, id} -> {id, params} end)

    request = Blocks.requests(id_to_params, &ByNumber.request(&1, false))
    error_message = &"Cannot fetch timestamps for blocks #{numbers}. Error: #{inspect(&1)}"

    case repeated_request(request, error_message, json_rpc_named_arguments, retries_left) do
      {:ok, response} ->
        %Blocks{blocks_params: blocks_params} = Blocks.from_responses(response, id_to_params)

        {:ok,
         blocks_params
         |> Enum.reduce(%{}, fn %{number: number, timestamp: timestamp}, acc -> Map.put_new(acc, number, timestamp) end)}

      err ->
        err
    end
  end

  def get_logs(from_block, to_block, address, topic0, json_rpc_named_arguments, retries_left) do
    req =
      request(%{
        id: 0,
        method: "eth_getLogs",
        params: [
          %{
            :fromBlock => integer_to_quantity(from_block),
            :toBlock => integer_to_quantity(to_block),
            :address => address,
            :topics => [topic0]
          }
        ]
      })

    case json_rpc(req, json_rpc_named_arguments) do
      {:ok, results} ->
        {:ok, results}

      {:error, message} ->
        retries_left = retries_left - 1

        error_message = "Cannot fetch logs for the block range #{from_block}..#{to_block}. Error: #{inspect(message)}"

        if retries_left <= 0 do
          Logger.error(error_message)
          {:error, message}
        else
          Logger.error("#{error_message} Retrying...")
          :timer.sleep(3000)
          get_logs(from_block, to_block, address, topic0, json_rpc_named_arguments, retries_left)
        end
    end
  end

  def get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left \\ 3)

  def get_transaction_by_hash(hash, _json_rpc_named_arguments, _retries_left) when is_nil(hash), do: {:ok, nil}

  def get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left) do
    req =
      request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    case json_rpc(req, json_rpc_named_arguments) do
      {:ok, tx} ->
        {:ok, tx}

      {:error, message} ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          {:error, message}
        else
          :timer.sleep(3000)
          get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left)
        end
    end
  end

  def get_new_filter(from_block, to_block, address, topic0, json_rpc_named_arguments, retries_left \\ 3) do
    processed_from_block = if is_integer(from_block), do: integer_to_quantity(from_block), else: from_block
    processed_to_block = if is_integer(to_block), do: integer_to_quantity(to_block), else: to_block

    req =
      request(%{
        id: 0,
        method: "eth_newFilter",
        params: [
          %{
            :fromBlock => processed_from_block,
            :toBlock => processed_to_block,
            :address => address,
            :topics => [topic0]
          }
        ]
      })

    error_message = &"Cannot create new log filter. Error: #{inspect(&1)}"

    repeated_request(req, error_message, json_rpc_named_arguments, retries_left)
  end

  def get_filter_changes(filter_id, json_rpc_named_arguments, retries_left \\ 3) do
    req =
      request(%{
        id: 0,
        method: "eth_getFilterChanges",
        params: [filter_id]
      })

    error_message = &"Cannot fetch filter changes. Error: #{inspect(&1)}"

    case repeated_request(req, error_message, json_rpc_named_arguments, retries_left) do
      {:error, %{code: _, message: "filter not found"}} -> {:error, :filter_not_found}
      response -> response
    end
  end

  defp repeated_request(req, error_message, json_rpc_named_arguments, retries_left) do
    case json_rpc(req, json_rpc_named_arguments) do
      {:ok, _results} = res ->
        res

      {:error, error} = err ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          Logger.error(error_message.(error))
          err
        else
          Logger.error("#{error_message.(error)} Retrying...")
          :timer.sleep(3000)
          repeated_request(req, error_message, json_rpc_named_arguments, retries_left)
        end
    end
  end

  def get_logs_range_size do
    @eth_get_logs_range_size
  end

  def json_rpc_named_arguments(optimism_l1_rpc) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: optimism_l1_rpc,
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  def init(env, contract_address, caller)
      when caller in [Indexer.Fetcher.OptimismWithdrawalEvent, Indexer.Fetcher.OptimismOutputRoot] do
    {contract_name, table_name, start_block_note} =
      if caller == Indexer.Fetcher.OptimismWithdrawalEvent do
        {"Optimism Portal", "op_withdrawal_events", "Withdrawals L1"}
      else
        {"Output Oracle", "op_output_roots", "Output Roots"}
      end

    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         optimism_l1_rpc <- Application.get_env(:indexer, :optimism_l1_rpc),
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_l1_rpc)},
         {:contract_is_valid, true} <- {:contract_is_valid, Helpers.is_address_correct?(contract_address)},
         start_block_l1 <- parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         {last_l1_block_number, last_l1_transaction_hash} <- caller.get_last_l1_item(),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         json_rpc_named_arguments <- json_rpc_named_arguments(optimism_l1_rpc),
         {:ok, last_l1_tx} <- get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_tx)},
         {:ok, last_safe_block} <- get_block_number_by_tag("safe", json_rpc_named_arguments),
         first_block <- max(last_safe_block - @block_check_interval_range_size, 1),
         {:ok, first_block_timestamp} <- get_block_timestamp_by_number(first_block, json_rpc_named_arguments),
         {:ok, last_safe_block_timestamp} <- get_block_timestamp_by_number(last_safe_block, json_rpc_named_arguments) do
      block_check_interval =
        ceil((last_safe_block_timestamp - first_block_timestamp) / (last_safe_block - first_block) * 1000 / 2)

      Logger.info("Block check interval is calculated as #{block_check_interval} ms.")

      start_block = max(start_block_l1, last_l1_block_number)

      reorg_monitor_task =
        Task.Supervisor.async_nolink(Module.concat(caller, TaskSupervisor), fn ->
          reorg_monitor(caller.fetcher_name(), block_check_interval, json_rpc_named_arguments)
        end)

      {:ok,
       %{
         contract_address: contract_address,
         block_check_interval: block_check_interval,
         start_block: start_block,
         end_block: last_safe_block,
         reorg_monitor_task: reorg_monitor_task,
         json_rpc_named_arguments: json_rpc_named_arguments
       }, {:continue, nil}}
    else
      {:start_block_l1_undefined, true} ->
        # the process shoudln't start if the start block is not defined
        :ignore

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        :ignore

      {:contract_is_valid, false} ->
        Logger.error("#{contract_name} contract address is invalid or not defined.")
        :ignore

      {:start_block_l1_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and #{table_name} table.")
        :ignore

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, last safe block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        :ignore

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check #{table_name} table."
        )

        :ignore

      _ ->
        Logger.error("#{start_block_note} Start Block is invalid or zero.")
        :ignore
    end
  end

  def log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, items_count, layer) do
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

  def parse_integer(integer_string) when is_binary(integer_string) do
    case Integer.parse(integer_string) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  def parse_integer(value) when is_integer(value) do
    value
  end

  def parse_integer(_integer_string), do: nil

  def reorg_monitor(fetcher_name, block_check_interval, json_rpc_named_arguments) do
    Logger.metadata(fetcher: fetcher_name)

    table_name = reorg_table_name(fetcher_name)

    # infinite loop
    Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), 0, fn _i, prev_latest ->
      {:ok, latest} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

      if latest < prev_latest do
        Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")
        reorg_block_push(table_name, latest)
      end

      :timer.sleep(block_check_interval)

      {:cont, latest}
    end)
  end

  def reorg_block_pop(fetcher_name) do
    table_name = reorg_table_name(fetcher_name)

    case BoundQueue.pop_front(reorg_queue_get(table_name)) do
      {:ok, {block_number, updated_queue}} ->
        :ets.insert(table_name, {:queue, updated_queue})
        block_number

      {:error, :empty} ->
        nil
    end
  end

  defp reorg_block_push(table_name, block_number) do
    {:ok, updated_queue} = BoundQueue.push_back(reorg_queue_get(table_name), block_number)
    :ets.insert(table_name, {:queue, updated_queue})
  end

  defp reorg_queue_get(table_name) do
    if :ets.whereis(table_name) == :undefined do
      :ets.new(table_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    with info when info != :undefined <- :ets.info(table_name),
         [{_, value}] <- :ets.lookup(table_name, :queue) do
      value
    else
      _ -> %BoundQueue{}
    end
  end

  defp reorg_table_name(fetcher_name) do
    :"#{fetcher_name}#{:_reorgs}"
  end
end
