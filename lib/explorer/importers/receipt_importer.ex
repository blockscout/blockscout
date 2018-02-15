defmodule Explorer.ReceiptImporter do
  @moduledoc "Imports a transaction receipt given a transaction hash."

  import Ecto.Query
  import Ethereumex.HttpClient, only: [eth_get_transaction_receipt: 1]

  alias Explorer.Address
  alias Explorer.Repo
  alias Explorer.Transaction
  alias Explorer.Receipt

  def import(hash) do
    transaction = hash |> find_transaction()
    hash
    |> download_receipt()
    |> extract_receipt()
    |> Map.put(:transaction_id, transaction.id)
    |> save_receipt()
  end

  @dialyzer {:nowarn_function, download_receipt: 1}
  defp download_receipt(hash) do
    {:ok, receipt} = eth_get_transaction_receipt(hash)
    receipt || %{}
  end

  defp find_transaction(hash) do
    query = from transaction in Transaction,
      left_join: receipt in assoc(transaction, :receipt),
      where: fragment("lower(?)", transaction.hash) == ^hash,
      where: is_nil(receipt.id),
      limit: 1
    Repo.one(query) || Transaction.null
  end

  defp save_receipt(receipt) do
    unless is_nil(receipt.transaction_id) do
      %Receipt{}
      |> Receipt.changeset(receipt)
      |> Repo.insert()
    end
  end

  defp extract_receipt(receipt) do
    logs = receipt["logs"] || []
    %{
      index: receipt["transactionIndex"] |> decode_integer_field(),
      cumulative_gas_used: receipt["cumulativeGasUsed"] |> decode_integer_field(),
      gas_used: receipt["gasUsed"] |> decode_integer_field(),
      status: receipt["status"] |> decode_integer_field(),
      logs: logs |> Enum.map(&extract_log/1)
    }
  end

  defp extract_log(log) do
    address = Address.find_or_create_by_hash(log["address"])
    %{
      address_id: address.id,
      index: log["logIndex"] |> decode_integer_field(),
      data: log["data"],
      type: log["type"],
      first_topic: log["topics"] |> Enum.at(0),
      second_topic: log["topics"] |> Enum.at(1),
      third_topic: log["topics"] |> Enum.at(2),
      fourth_topic: log["topics"] |> Enum.at(3),
    }
  end

  defp decode_integer_field("0x" <> hex) when is_binary(hex) do
    String.to_integer(hex, 16)
  end
  defp decode_integer_field(field), do: field
end
