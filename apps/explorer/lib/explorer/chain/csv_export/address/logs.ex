defmodule Explorer.Chain.CsvExport.Address.Logs do
  @moduledoc """
  Exports logs to a csv file.
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.CsvExport.Helper

  @spec export(Hash.Address.t(), String.t(), String.t(), Keyword.t(), String.t() | nil, String.t() | nil) ::
          Enumerable.t()
  def export(address_hash, from_period, to_period, _options, _filter_type \\ nil, filter_value \\ nil) do
    {from_block, to_block} = Helper.block_from_period(from_period, to_period)

    address_hash
    |> fetch_all_logs(from_block, to_block, filter_value, Helper.paging_options())
    |> to_csv_format()
    |> Helper.dump_to_stream()
  end

  defp fetch_all_logs(address_hash, from_block, to_block, filter_value, paging_options) do
    options =
      []
      |> Keyword.put(:paging_options, paging_options)
      |> Keyword.put(:from_block, from_block)
      |> Keyword.put(:to_block, to_block)
      |> Keyword.put(:topic, filter_value)

    Chain.address_to_logs(address_hash, true, options)
  end

  defp to_csv_format(logs) do
    row_names = [
      "TxHash",
      "Index",
      "BlockNumber",
      "BlockHash",
      "ContractAddress",
      "Data",
      "FirstTopic",
      "SecondTopic",
      "ThirdTopic",
      "FourthTopic"
    ]

    log_lists =
      logs
      |> Stream.map(fn log ->
        [
          to_string(log.transaction_hash),
          log.index,
          log.block_number,
          log.block_hash,
          Address.checksum(log.address_hash),
          to_string(log.data),
          to_string(log.first_topic),
          to_string(log.second_topic),
          to_string(log.third_topic),
          to_string(log.fourth_topic)
        ]
      end)

    Stream.concat([row_names], log_lists)
  end
end
