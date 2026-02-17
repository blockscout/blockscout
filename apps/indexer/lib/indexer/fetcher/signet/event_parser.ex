defmodule Indexer.Fetcher.Signet.EventParser do
  @moduledoc """
  Parses Signet Order and Filled events from transaction logs.

  Event signatures and ABI types are sourced from @signet-sh/sdk.
  See `Indexer.Fetcher.Signet.Abi` for topic hash computation.

  ## Event Structures (from @signet-sh/sdk)

  ### Order Event
  ```
  Order(uint256 deadline, Input[] inputs, Output[] outputs)
  ```
  Where:
  - Input = (address token, uint256 amount)
  - Output = (address token, uint256 amount, address recipient, uint32 chainId)

  ### Filled Event
  ```
  Filled(Output[] outputs)
  ```

  ### Sweep Event
  ```
  Sweep(address indexed recipient, address indexed token, uint256 amount)
  ```

  ## Architecture Note

  Orders and fills are indexed independently. Direct correlation between orders
  and their fills is not possible at the indexer level - only block-level
  coordination is available. The data is stored separately for querying and
  analytics purposes.
  """

  require Logger

  alias Indexer.Fetcher.Signet.Abi

  @doc """
  Parse logs from the RollupOrders contract.

  Returns {:ok, {orders, fills}} where orders and fills are lists of maps
  ready for database import.
  """
  @spec parse_rollup_logs([map()]) :: {:ok, {[map()], [map()]}}
  def parse_rollup_logs(logs) when is_list(logs) do
    order_topic = Abi.order_event_topic()
    filled_topic = Abi.filled_event_topic()
    sweep_topic = Abi.sweep_event_topic()

    {orders, fills, sweeps} =
      Enum.reduce(logs, {[], [], []}, fn log, {orders_acc, fills_acc, sweeps_acc} ->
        topic = get_topic(log, 0)

        cond do
          topic == order_topic ->
            case parse_order_event(log) do
              {:ok, order} -> {[order | orders_acc], fills_acc, sweeps_acc}
              {:error, reason} ->
                Logger.warning("Failed to parse Order event: #{inspect(reason)}")
                {orders_acc, fills_acc, sweeps_acc}
            end

          topic == filled_topic ->
            case parse_filled_event(log) do
              {:ok, fill} -> {orders_acc, [fill | fills_acc], sweeps_acc}
              {:error, reason} ->
                Logger.warning("Failed to parse Filled event: #{inspect(reason)}")
                {orders_acc, fills_acc, sweeps_acc}
            end

          topic == sweep_topic ->
            case parse_sweep_event(log) do
              {:ok, sweep} -> {orders_acc, fills_acc, [sweep | sweeps_acc]}
              {:error, reason} ->
                Logger.warning("Failed to parse Sweep event: #{inspect(reason)}")
                {orders_acc, fills_acc, sweeps_acc}
            end

          true ->
            {orders_acc, fills_acc, sweeps_acc}
        end
      end)

    # Associate sweeps with their corresponding orders by transaction hash
    orders_with_sweeps = associate_sweeps_with_orders(orders, sweeps)

    {:ok, {Enum.reverse(orders_with_sweeps), Enum.reverse(fills)}}
  end

  @doc """
  Parse Filled events from the HostOrders contract.

  Returns {:ok, fills} where fills is a list of maps ready for database import.
  """
  @spec parse_host_filled_logs([map()]) :: {:ok, [map()]}
  def parse_host_filled_logs(logs) when is_list(logs) do
    filled_topic = Abi.filled_event_topic()

    fills =
      logs
      |> Enum.filter(fn log -> get_topic(log, 0) == filled_topic end)
      |> Enum.map(&parse_filled_event/1)
      |> Enum.filter(fn
        {:ok, _} -> true
        {:error, reason} ->
          Logger.warning("Failed to parse host Filled event: #{inspect(reason)}")
          false
      end)
      |> Enum.map(fn {:ok, fill} -> fill end)

    {:ok, fills}
  end

  # Parse Order event
  # Order(uint256 deadline, Input[] inputs, Output[] outputs)
  defp parse_order_event(log) do
    data = get_log_data(log)

    with {:ok, decoded} <- decode_order_data(data) do
      {deadline, inputs, outputs} = decoded

      order = %{
        deadline: deadline,
        block_number: parse_block_number(log),
        transaction_hash: get_transaction_hash(log),
        log_index: parse_log_index(log),
        inputs_json: Jason.encode!(format_inputs(inputs)),
        outputs_json: Jason.encode!(format_outputs(outputs))
      }

      {:ok, order}
    end
  end

  # Parse Filled event
  # Filled(Output[] outputs)
  defp parse_filled_event(log) do
    data = get_log_data(log)

    with {:ok, outputs} <- decode_filled_data(data) do
      fill = %{
        block_number: parse_block_number(log),
        transaction_hash: get_transaction_hash(log),
        log_index: parse_log_index(log),
        outputs_json: Jason.encode!(format_outputs(outputs))
      }

      {:ok, fill}
    end
  end

  # Parse Sweep event
  # Sweep(address indexed recipient, address indexed token, uint256 amount)
  # Note: recipient and token are indexed (in topics), amount is in data
  defp parse_sweep_event(log) do
    data = get_log_data(log)

    with {:ok, amount} <- decode_sweep_data(data) do
      # recipient is in topic[1], token is in topic[2]
      recipient = get_indexed_address(log, 1)
      token = get_indexed_address(log, 2)

      sweep = %{
        transaction_hash: get_transaction_hash(log),
        recipient: recipient,
        token: token,
        amount: amount
      }

      {:ok, sweep}
    end
  end

  # Decode Order event data
  # Order(uint256 deadline, Input[] inputs, Output[] outputs)
  # Input = (address token, uint256 amount)
  # Output = (address token, uint256 amount, address recipient, uint32 chainId)
  defp decode_order_data(data) when is_binary(data) do
    try do
      # ABI decode: uint256, dynamic array offset, dynamic array offset
      <<deadline::unsigned-big-integer-size(256),
        inputs_offset::unsigned-big-integer-size(256),
        outputs_offset::unsigned-big-integer-size(256),
        rest::binary>> = data

      # Parse inputs array - offset is from start of data (after first 32 bytes)
      inputs_data = binary_part(rest, inputs_offset - 96, byte_size(rest) - inputs_offset + 96)
      inputs = decode_input_array(inputs_data)

      # Parse outputs array
      outputs_data = binary_part(rest, outputs_offset - 96, byte_size(rest) - outputs_offset + 96)
      outputs = decode_output_array(outputs_data)

      {:ok, {deadline, inputs, outputs}}
    rescue
      e ->
        Logger.error("Error decoding Order data: #{inspect(e)}")
        {:error, :decode_failed}
    end
  end

  defp decode_order_data(_), do: {:error, :invalid_data}

  # Decode Filled event data
  # Filled(Output[] outputs)
  defp decode_filled_data(data) when is_binary(data) do
    try do
      <<_offset::unsigned-big-integer-size(256), rest::binary>> = data
      outputs = decode_output_array(rest)
      {:ok, outputs}
    rescue
      e ->
        Logger.error("Error decoding Filled data: #{inspect(e)}")
        {:error, :decode_failed}
    end
  end

  defp decode_filled_data(_), do: {:error, :invalid_data}

  # Decode Sweep event data
  # Only amount is in data (recipient and token are indexed)
  defp decode_sweep_data(data) when is_binary(data) do
    try do
      <<amount::unsigned-big-integer-size(256)>> = data
      {:ok, amount}
    rescue
      e ->
        Logger.error("Error decoding Sweep data: #{inspect(e)}")
        {:error, :decode_failed}
    end
  end

  defp decode_sweep_data(_), do: {:error, :invalid_data}

  # Decode array of Input tuples
  # Input = (address token, uint256 amount)
  defp decode_input_array(<<length::unsigned-big-integer-size(256), rest::binary>>) do
    decode_inputs(rest, length, [])
  end

  defp decode_inputs(_data, 0, acc), do: Enum.reverse(acc)

  defp decode_inputs(<<_padding::binary-size(12),
                       token::binary-size(20),
                       amount::unsigned-big-integer-size(256),
                       rest::binary>>, count, acc) do
    input = {token, amount}
    decode_inputs(rest, count - 1, [input | acc])
  end

  # Decode array of Output tuples
  # Output = (address token, uint256 amount, address recipient, uint32 chainId)
  defp decode_output_array(<<length::unsigned-big-integer-size(256), rest::binary>>) do
    decode_outputs(rest, length, [])
  end

  defp decode_outputs(_data, 0, acc), do: Enum.reverse(acc)

  defp decode_outputs(<<_padding1::binary-size(12),
                        token::binary-size(20),
                        amount::unsigned-big-integer-size(256),
                        _padding2::binary-size(12),
                        recipient::binary-size(20),
                        _padding3::binary-size(28),
                        chain_id::unsigned-big-integer-size(32),
                        rest::binary>>, count, acc) do
    # Output struct order: token, amount, recipient, chainId
    output = {token, amount, recipient, chain_id}
    decode_outputs(rest, count - 1, [output | acc])
  end

  # Associate sweep events with their corresponding orders by transaction hash
  defp associate_sweeps_with_orders(orders, sweeps) do
    sweeps_by_tx = Enum.group_by(sweeps, & &1.transaction_hash)

    Enum.map(orders, fn order ->
      case Map.get(sweeps_by_tx, order.transaction_hash) do
        [sweep | _] ->
          Map.merge(order, %{
            sweep_recipient: sweep.recipient,
            sweep_token: sweep.token,
            sweep_amount: sweep.amount
          })

        _ ->
          order
      end
    end)
  end

  # Format inputs for JSON storage
  defp format_inputs(inputs) do
    Enum.map(inputs, fn {token, amount} ->
      %{
        "token" => format_address(token),
        "amount" => Integer.to_string(amount)
      }
    end)
  end

  # Format outputs for JSON storage
  # Output = (token, amount, recipient, chainId)
  defp format_outputs(outputs) do
    Enum.map(outputs, fn {token, amount, recipient, chain_id} ->
      %{
        "token" => format_address(token),
        "amount" => Integer.to_string(amount),
        "recipient" => format_address(recipient),
        "chainId" => chain_id
      }
    end)
  end

  defp format_address(bytes) when is_binary(bytes) and byte_size(bytes) == 20 do
    "0x" <> Base.encode16(bytes, case: :lower)
  end

  defp get_topic(log, index) do
    topics = Map.get(log, "topics") || Map.get(log, :topics) || []
    Enum.at(topics, index)
  end

  # Get an indexed address from topics (topics contain 32-byte padded addresses)
  defp get_indexed_address(log, topic_index) do
    topic = get_topic(log, topic_index)

    case topic do
      "0x" <> hex ->
        # Take last 40 chars (20 bytes) of the 64-char hex string
        address_hex = String.slice(hex, -40, 40)
        Base.decode16!(address_hex, case: :mixed)

      bytes when is_binary(bytes) and byte_size(bytes) == 32 ->
        # Take last 20 bytes
        binary_part(bytes, 12, 20)

      _ ->
        nil
    end
  end

  defp get_log_data(log) do
    data = Map.get(log, "data") || Map.get(log, :data) || ""

    case data do
      "0x" <> hex -> Base.decode16!(hex, case: :mixed)
      hex when is_binary(hex) -> Base.decode16!(hex, case: :mixed)
      _ -> ""
    end
  end

  defp get_transaction_hash(log) do
    hash = Map.get(log, "transactionHash") || Map.get(log, :transaction_hash)

    case hash do
      "0x" <> _ -> hash
      bytes when is_binary(bytes) -> "0x" <> Base.encode16(bytes, case: :lower)
      _ -> nil
    end
  end

  defp parse_block_number(log) do
    block = Map.get(log, "blockNumber") || Map.get(log, :block_number)

    case block do
      "0x" <> hex ->
        {num, ""} = Integer.parse(hex, 16)
        num

      num when is_integer(num) ->
        num

      _ ->
        0
    end
  end

  defp parse_log_index(log) do
    index = Map.get(log, "logIndex") || Map.get(log, :log_index)

    case index do
      "0x" <> hex ->
        {num, ""} = Integer.parse(hex, 16)
        num

      num when is_integer(num) ->
        num

      _ ->
        0
    end
  end
end
