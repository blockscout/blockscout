defmodule Explorer.Chain.AddressTransactionCsvExporter do
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Transaction}

  @necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [token_transfers: :token] => :optional,
      [token_transfers: :to_address] => :optional,
      [token_transfers: :from_address] => :optional,
      [token_transfers: :token_contract_address] => :optional,
      :block => :required
    }
  ]

  def export(address) do
    address
    |> Chain.address_to_transactions_with_rewards(@necessity_by_association)
    |> to_csv_format(address)
    |> dump_data_to_csv()
  end

  defp dump_data_to_csv(transactions) do
    {:ok, path} = Briefly.create()

    transactions
    |> NimbleCSV.RFC4180.dump_to_stream()
    |> Stream.into(File.stream!(path))
    |> Enum.to_list()

    path
  end

  defp to_csv_format(transactions, address) do
    # , "ETHCurrentPrice", "ETHPriceAtTxDate", "TxFee", "Status", "ErrCode"]
    row_names = [
      "TxHash",
      "BlockNumber",
      "UnixTimestamp",
      "FromAddress",
      "ToAddress",
      "ContractAddress",
      "Type",
      "Value"
    ]

    transaction_lists =
      transactions
      |> Stream.map(fn transaction ->
        [
          to_string(transaction.hash),
          transaction.block_number,
          transaction.block.timestamp,
          to_string(transaction.from_address),
          to_string(transaction.to_address),
          to_string(transaction.created_contract_address),
          type(transaction, address),
          1
        ]
      end)

    Stream.concat([row_names], transaction_lists)
  end

  defp type(%Transaction{from_address_hash: from_address}, %Address{hash: from_address}), do: "OUT"

  defp type(%Transaction{to_address_hash: to_address}, %Address{hash: to_address}), do: "IN"

  defp type(_, _), do: ""
end
