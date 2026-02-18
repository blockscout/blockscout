defmodule BlockScoutWeb.API.RPC.LogsView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias Explorer.Chain.Data
  alias Explorer.Helper

  def render("getlogs.json", %{logs: logs}) do
    data = Enum.map(logs, &prepare_log/1)
    RPCView.render("show.json", data: data)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_log(log) do
    IO.inspect(log.data, label: "log.data")
    IO.inspect(log.compressed_data_lz4, label: "log.compressed_data_lz4")

    decompressed = decompress_lz4(log.compressed_data_lz4)
    IO.inspect(decompressed, label: "decompressed_lz4")

    %{
      "address" => "#{log.address_hash}",
      "topics" => get_topics(log),
      "data" => "#{decompressed || log.data}",
      "blockNumber" => Helper.integer_to_hex(log.block_number),
      "timeStamp" => Helper.datetime_to_hex(log.block_timestamp),
      "gasPrice" => Helper.decimal_to_hex(log.gas_price.value),
      "gasUsed" => Helper.decimal_to_hex(log.gas_used),
      "logIndex" => Helper.integer_to_hex(log.index),
      "transactionHash" => "#{log.transaction_hash}",
      "transactionIndex" => Helper.integer_to_hex(log.transaction_index)
    }
  end

  defp get_topics(%{
         first_topic: first_topic,
         second_topic: second_topic,
         third_topic: third_topic,
         fourth_topic: fourth_topic
       }) do
    [first_topic, second_topic, third_topic, fourth_topic]
  end

  # Decompresses LZ4 compressed data and wraps it in Data struct
  # Also measures decompression overhead (time taken to decompress)
  defp decompress_lz4(nil), do: nil

  defp decompress_lz4(compressed_data) when is_binary(compressed_data) do
    start_time = System.monotonic_time(:microsecond)

    # lz4_erl's uncompress/2 requires maximum uncompressed size
    # Try with increasing buffer sizes to handle various compression ratios
    compressed_size = byte_size(compressed_data)

    decompressed =
      Enum.find_value([10, 50, 100, 500], fn multiplier ->
        try do
          case :lz4.uncompress(compressed_data, compressed_size * multiplier) do
            {:ok, decompressed} -> decompressed
            decompressed when is_binary(decompressed) -> decompressed
            _ -> nil
          end
        rescue
          _ -> nil
        end
      end)

    end_time = System.monotonic_time(:microsecond)
    decompression_time_us = end_time - start_time

    if decompressed do
      original_size = byte_size(decompressed)
      compressed_ratio = original_size / max(byte_size(compressed_data), 1)

      IO.inspect(
        %{
          compressed_size_bytes: byte_size(compressed_data),
          decompressed_size_bytes: original_size,
          compression_ratio: Float.round(compressed_ratio, 2),
          decompression_time_us: decompression_time_us,
          decompression_overhead_percent:
            Float.round((decompression_time_us / max(original_size, 1)) * 100, 2)
        },
        label: "LZ4 Decompression Metrics"
      )

      %Data{bytes: decompressed}
    else
      nil
    end
  end

  defp decompress_lz4(_), do: nil
end
