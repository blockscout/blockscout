defmodule Explorer.TransactionReceiptImporter do
  @moduledoc "Imports a transaction receipt given a transaction hash."

  import Ecto.Query
  import Ethereumex.HttpClient, only: [eth_get_transaction_receipt: 1]

  alias Explorer.Repo
  alias Explorer.Transaction
  alias Explorer.TransactionReceipt

  def import(hash) do
    hash
    |> download_receipt()
    |> ingest_receipt()
    |> save_receipt()
  end

  @dialyzer {:nowarn_function, download_receipt: 1}
  defp download_receipt(hash) do
    {:ok, receipt} = eth_get_transaction_receipt(hash)
    receipt || %{}
  end

  defp ingest_receipt(receipt) do
    hash = String.downcase("#{receipt["transactionHash"]}")
    query = from transaction in Transaction,
      left_join: receipt in assoc(transaction, :receipt),
      where: fragment("lower(?)", transaction.hash) == ^hash,
      where: is_nil(receipt.id),
      limit: 1
    transaction = Repo.one(query) || Transaction.null
    receipt
    |> extract_receipt()
    |> Map.put(:transaction_id, transaction.id)
  end

  defp save_receipt(receipt) do
    unless is_nil(receipt.transaction_id) do
      %TransactionReceipt{}
      |> TransactionReceipt.changeset(receipt)
      |> Repo.insert()
    end
  end

  defp extract_receipt(receipt) do
    %{
      index: receipt["transactionIndex"] |> decode_integer_field(),
      cumulative_gas_used: receipt["cumulativeGasUsed"] |> decode_integer_field(),
      gas_used: receipt["gasUsed"] |> decode_integer_field(),
      status: receipt["status"] |> decode_integer_field(),
    }
  end

  defp decode_integer_field("0x" <> hex) when is_binary(hex) do
    String.to_integer(hex, 16)
  end
  defp decode_integer_field(field), do: field
end
