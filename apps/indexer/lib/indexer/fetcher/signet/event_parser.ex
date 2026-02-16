defmodule Indexer.Fetcher.Signet.EventParser do
  @moduledoc """
  Parses Signet Order and Filled events from transaction logs.

  Handles ABI decoding for:
  - Order(uint256 deadline, Input[] inputs, Output[] outputs)
  - Filled(Output[] outputs)
  - Sweep(address recipient, address token, uint256 amount)

  Where:
  - Input = (address token, uint256 amount)
  - Output = (address recipient, address token, uint256 amount)
  """

  require Logger

  # Event topic hashes
  @order_event_topic "0x" <>
                       Base.encode16(
                         ExKeccak.hash_256("Order(uint256,(address,uint256)[],(address,address,uint256)[])"),
                         case: :lower
                       )

  @filled_event_topic "0x" <>
                        Base.encode16(
                          ExKeccak.hash_256("Filled((address,address,uint256)[])"),
                          case: :lower
                        )

  @sweep_event_topic "0x" <>
                       Base.encode16(
                         ExKeccak.hash_256("Sweep(address,address,uint256)"),
                         case: :lower
                       )

  @doc """
  Parse logs from the RollupOrders contract.

  Returns {:ok, {orders, fills}} where orders and fills are lists of maps
  ready for database import.
  """
  @spec parse_rollup_logs([map()]) :: {:ok, {[map()], [map()]}}
  def parse_rollup_logs(logs) when is_list(logs) do
    {orders, fills, sweeps} =
      Enum.reduce(logs, {[], [], []}, fn log, {orders_acc, fills_acc, sweeps_acc} ->
        topic = get_topic(log, 0)

        cond do
          topic == @order_event_topic ->
            case parse_order_event(log) do
              {:ok, order} -> {[order | orders_acc], fills_acc, sweeps_acc}
              {:error, reason} ->
                Logger.warning("Failed to parse Order event: #{inspect(reason)}")
                {orders_acc, fills_acc, sweeps_acc}
            end

          topic == @filled_event_topic ->
            case parse_filled_event(log) do
              {:ok, fill} -> {orders_acc, [fill | fills_acc], sweeps_acc}
              {:error, reason} ->
                Logger.warning("Failed to parse Filled event: #{inspect(reason)}")
                {orders_acc, fills_acc, sweeps_acc}
            end

          topic == @sweep_event_topic ->
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
    fills =
      logs
      |> Enum.filter(fn log -> get_topic(log, 0) == @filled_event_topic end)
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

  @doc """
  Compute the outputs_witness_hash for a list of outputs.

  The hash is computed as: keccak256(concat(keccak256(abi_encode(output)) for output in outputs))
  """
  @spec compute_outputs_witness_hash([{binary(), binary(), non_neg_integer()}]) :: binary()
  def compute_outputs_witness_hash(outputs) do
    output_hashes =
      outputs
      |> Enum.map(fn {recipient, token, amount} ->
        # ABI-encode each output as (address, address, uint256)
        encoded =
          <<0::size(96)>> <>
          normalize_address(recipient) <>
          <<0::size(96)>> <>
          normalize_address(token) <>
          <<amount::unsigned-big-integer-size(256)>>

        ExKeccak.hash_256(encoded)
      end)
      |> Enum.join()

    ExKeccak.hash_256(output_hashes)
  end

  # Parse Order event
  defp parse_order_event(log) do
    data = get_log_data(log)

    with {:ok, decoded} <- decode_order_data(data) do
      {deadline, inputs, outputs} = decoded

      outputs_witness_hash = compute_outputs_witness_hash(outputs)

      order = %{
        outputs_witness_hash: outputs_witness_hash,
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
  defp parse_filled_event(log) do
    data = get_log_data(log)

    with {:ok, outputs} <- decode_filled_data(data) do
      outputs_witness_hash = compute_outputs_witness_hash(outputs)

      fill = %{
        outputs_witness_hash: outputs_witness_hash,
        block_number: parse_block_number(log),
        transaction_hash: get_transaction_hash(log),
        log_index: parse_log_index(log),
        outputs_json: Jason.encode!(format_outputs(outputs))
      }

      {:ok, fill}
    end
  end

  # Parse Sweep event
  defp parse_sweep_event(log) do
    data = get_log_data(log)

    with {:ok, {recipient, token, amount}} <- decode_sweep_data(data) do
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
  # Output = (address recipient, address token, uint256 amount)
  defp decode_order_data(data) when is_binary(data) do
    try do
      # ABI decode: uint256, (address,uint256)[], (address,address,uint256)[]
      # For dynamic arrays, we have offsets first, then the actual data

      <<deadline::unsigned-big-integer-size(256),
        inputs_offset::unsigned-big-integer-size(256),
        outputs_offset::unsigned-big-integer-size(256),
        rest::binary>> = data

      # Parse inputs array
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
  # Sweep(address recipient, address token, uint256 amount)
  defp decode_sweep_data(data) when is_binary(data) do
    try do
      <<_padding1::binary-size(12),
        recipient::binary-size(20),
        _padding2::binary-size(12),
        token::binary-size(20),
        amount::unsigned-big-integer-size(256)>> = data

      {:ok, {recipient, token, amount}}
    rescue
      e ->
        Logger.error("Error decoding Sweep data: #{inspect(e)}")
        {:error, :decode_failed}
    end
  end

  defp decode_sweep_data(_), do: {:error, :invalid_data}

  # Decode array of Input tuples
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
  defp decode_output_array(<<length::unsigned-big-integer-size(256), rest::binary>>) do
    decode_outputs(rest, length, [])
  end

  defp decode_outputs(_data, 0, acc), do: Enum.reverse(acc)

  defp decode_outputs(<<_padding1::binary-size(12),
                        recipient::binary-size(20),
                        _padding2::binary-size(12),
                        token::binary-size(20),
                        amount::unsigned-big-integer-size(256),
                        rest::binary>>, count, acc) do
    output = {recipient, token, amount}
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
  defp format_outputs(outputs) do
    Enum.map(outputs, fn {recipient, token, amount} ->
      %{
        "recipient" => format_address(recipient),
        "token" => format_address(token),
        "amount" => Integer.to_string(amount)
      }
    end)
  end

  defp format_address(bytes) when is_binary(bytes) and byte_size(bytes) == 20 do
    "0x" <> Base.encode16(bytes, case: :lower)
  end

  defp normalize_address(bytes) when is_binary(bytes) and byte_size(bytes) == 20, do: bytes

  defp normalize_address("0x" <> hex) when byte_size(hex) == 40 do
    Base.decode16!(hex, case: :mixed)
  end

  defp get_topic(log, index) do
    topics = Map.get(log, "topics") || Map.get(log, :topics) || []
    Enum.at(topics, index)
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
