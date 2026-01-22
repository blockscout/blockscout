defmodule Indexer.Transform.FheOperations do
  @moduledoc """
  Parses FHE (Fully Homomorphic Encryption) operations from transaction logs during indexing.

  This module extracts FHE operations from logs, calculates HCU metrics, and prepares
  data for database insertion.
  """

  alias Explorer.Chain.Fhe.Parser

  @doc """
  Parses FHE operations from a list of logs.

  Returns a map with :fhe_operations key containing a list of params ready for database insertion.
  """
  @spec parse(list()) :: %{fhe_operations: list()}
  def parse(logs) do
    filtered_logs = filter_fhe_logs(logs)

    fhe_operations =
      filtered_logs
      |> group_by_transaction()
      |> parse_all_transactions()
      |> List.flatten()

    %{fhe_operations: fhe_operations}
  end

  @doc """
  Filters logs to only include FHE-related events.
  """
  defp filter_fhe_logs(logs) do
    all_events = Parser.all_fhe_events()

    Enum.filter(logs, fn log ->
      case log.first_topic do
        nil -> false
        "" -> false
        topic ->
          normalized = sanitize_first_topic(topic)
          normalized in all_events
      end
    end)
  end

  defp group_by_transaction(logs) do
    Enum.group_by(logs, & &1.transaction_hash)
  end

  defp parse_all_transactions(grouped_logs) do
    Enum.map(grouped_logs, fn {_tx_hash, tx_logs} ->
      parse_transaction_logs(tx_logs)
    end)
  end

  defp parse_transaction_logs(tx_logs) when is_list(tx_logs) and length(tx_logs) > 0 do
    # Get first log to extract common fields
    first_log = hd(tx_logs)
    transaction_hash = first_log.transaction_hash
    block_hash = first_log.block_hash
    block_number = first_log.block_number

    # Sort logs by index to ensure correct HCU depth calculation order
    sorted_logs = Enum.sort_by(tx_logs, & &1.index)

    # Parse operations using shared Parser logic
    operations = Enum.map(sorted_logs, &parse_single_log/1)

    # Build HCU depth map
    hcu_depth_map = Parser.build_hcu_depth_map(operations)

    # Convert to database params
    Enum.map(operations, fn op ->
      result_handle_key = if is_binary(op.result), do: Base.encode16(op.result, case: :lower), else: "unknown"

      %{
        transaction_hash: transaction_hash,
        block_hash: block_hash,
        log_index: op.log_index,
        block_number: block_number,
        operation: op.operation,
        operation_type: op.type,
        fhe_type: op.fhe_type,
        is_scalar: op.is_scalar,
        hcu_cost: op.hcu_cost,
        hcu_depth: Map.get(hcu_depth_map, result_handle_key, op.hcu_cost),
        caller: op.caller,
        result_handle: op.result,
        input_handles: op.inputs
      }
    end)
  end

  defp parse_transaction_logs(_), do: []

  defp parse_single_log(log) do
    event_name = Parser.get_event_name(log.first_topic)
    caller = extract_caller_binary(log.second_topic)
    operation_data = Parser.decode_event_data(log, event_name)
    
    fhe_type = Parser.extract_fhe_type(operation_data, event_name)
    is_scalar = Map.get(operation_data, :scalar_byte) == <<0x01>>
    hcu_cost = Parser.calculate_hcu_cost(event_name, fhe_type, is_scalar)
    
    %{
      log_index: log.index,
      operation: event_name,
      type: Parser.get_operation_type(event_name),
      fhe_type: fhe_type,
      is_scalar: is_scalar,
      hcu_cost: hcu_cost,
      caller: caller,
      inputs: Parser.extract_inputs(operation_data, event_name),
      result: operation_data[:result] || <<0::256>>
    }
  end

  # Helper functions

  defp sanitize_first_topic(%Explorer.Chain.Data{bytes: bytes}), do: "0x" <> Base.encode16(bytes, case: :lower)
  defp sanitize_first_topic(topic) when is_binary(topic), do: String.downcase(topic)
  defp sanitize_first_topic(_), do: ""

  # We need specific binary extraction for caller here because Indexer might deal with raw binaries differently than Explorer
  defp extract_caller_binary(nil), do: nil

  defp extract_caller_binary("0x" <> hex_data) when byte_size(hex_data) == 64 do
    case Base.decode16(hex_data, case: :mixed) do
      {:ok, bytes} -> extract_caller_binary(bytes)
      _ -> nil
    end
  end

  defp extract_caller_binary(topic) when is_binary(topic) and byte_size(topic) == 32 do
    <<_::binary-size(12), address::binary-size(20)>> = topic
    address
  end

  defp extract_caller_binary(%Explorer.Chain.Hash{bytes: bytes}) when byte_size(bytes) >= 32 do
    <<_::binary-size(12), address::binary-size(20)>> = bytes
    address
  end

  defp extract_caller_binary(%Explorer.Chain.Data{bytes: bytes}) when byte_size(bytes) >= 32 do
    <<_::binary-size(12), address::binary-size(20)>> = bytes
    address
  end

  defp extract_caller_binary(_), do: nil
end
