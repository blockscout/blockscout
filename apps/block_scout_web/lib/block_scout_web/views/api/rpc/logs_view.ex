defmodule BlockScoutWeb.API.RPC.LogsView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias Explorer.Helper

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
end
