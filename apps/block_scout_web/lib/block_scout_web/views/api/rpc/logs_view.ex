defmodule BlockScoutWeb.API.RPC.LogsView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("getlogs.json", %{logs: logs}) do
    data = Enum.map(logs, &prepare_log/1)
    RPCView.render("show.json", data: data)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_log(log) do
    %{
      "address" => "#{log.address_hash}",
      "topics" => get_topics(log),
      "data" => "#{log.data}",
      "blockNumber" => integer_to_hex(log.block_number),
      "timeStamp" => datetime_to_hex(log.block_timestamp),
      "gasPrice" => decimal_to_hex(log.gas_price.value),
      "gasUsed" => decimal_to_hex(log.gas_used),
      "logIndex" => integer_to_hex(log.index),
      "transactionHash" => "#{log.transaction_hash}",
      "transactionIndex" => integer_to_hex(log.transaction_index)
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

  defp integer_to_hex(integer), do: "0x" <> String.downcase(Integer.to_string(integer, 16))

  defp decimal_to_hex(decimal) do
    decimal
    |> Decimal.to_integer()
    |> integer_to_hex()
  end

  defp datetime_to_hex(nil), do: nil

  defp datetime_to_hex(datetime) do
    datetime
    |> DateTime.to_unix()
    |> integer_to_hex()
  end
end
