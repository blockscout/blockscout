defmodule Explorer.Chain.AddressLogCsvExporter do
  @moduledoc """
  Exports internal transactions to a csv file.
  """

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{Address, Log, Transaction}
  alias NimbleCSV.RFC4180

  @page_size 150

  @paging_options %PagingOptions{page_size: @page_size + 1}

  @spec export(Address.t(), String.t(), String.t()) :: Enumerable.t()
  def export(address, from_period, to_period) do
    from_block = Chain.convert_date_to_min_block(from_period)
    to_block = Chain.convert_date_to_max_block(to_period)

    address.hash
    |> fetch_all_logs(from_block, to_block, @paging_options)
    |> to_csv_format()
    |> dump_to_stream()
  end

  defp fetch_all_logs(address_hash, from_block, to_block, paging_options, acc \\ []) do
    options =
      []
      |> Keyword.put(:paging_options, paging_options)
      |> Keyword.put(:from_block, from_block)
      |> Keyword.put(:to_block, to_block)

    logs = Chain.address_to_logs(address_hash, options)

    new_acc = logs ++ acc

    case Enum.split(logs, @page_size) do
      {_logs, [%Log{block_number: block_number, transaction: %Transaction{index: transaction_index}, index: index}]} ->
        new_paging_options = %{@paging_options | key: {block_number, transaction_index, index}}
        fetch_all_logs(address_hash, from_block, to_block, new_paging_options, new_acc)

      {_, []} ->
        new_acc
    end
  end

  defp dump_to_stream(logs) do
    logs
    |> RFC4180.dump_to_stream()
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
          to_string(log.address_hash),
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
