defmodule BlockScoutWeb.API.V2.EthereumView do
  alias Explorer.Chain.{Block, Transaction}

  defp count_blob_transactions(%Block{transactions: txs}) when is_list(txs),
    # EIP-2718 blob transaction type
    do: Enum.count(txs, &(&1.type == 3))

  defp count_blob_transactions(_), do: nil

  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    case Map.get(transaction, :beacon_blob_transaction) do
      nil ->
        out_json

      %Ecto.Association.NotLoaded{} ->
        out_json

      item ->
        out_json
        |> Map.put("max_fee_per_blob_gas", item.max_fee_per_blob_gas)
        |> Map.put("blob_versioned_hashes", item.blob_versioned_hashes)
        |> Map.put("blob_gas_used", item.blob_gas_used)
        |> Map.put("blob_gas_price", item.blob_gas_price)
        |> Map.put("burnt_blob_fee", Decimal.mult(item.blob_gas_used, item.blob_gas_price))
    end
  end

  def extend_block_json_response(out_json, %Block{} = block, single_block?) do
    blob_gas_used = Map.get(block, :blob_gas_used)
    excess_blob_gas = Map.get(block, :excess_blob_gas)

    extended_out_json =
      out_json
      |> Map.put("blob_tx_count", count_blob_transactions(block))
      |> Map.put("blob_gas_used", blob_gas_used)
      |> Map.put("excess_blob_gas", excess_blob_gas)

    if single_block? do
      blob_gas_price = Block.transaction_blob_gas_price(block.transactions)
      burnt_blob_transaction_fees = Decimal.mult(blob_gas_used || 0, blob_gas_price || 0)

      extended_out_json
      |> Map.put("blob_gas_price", blob_gas_price)
      |> Map.put("burnt_blob_fees", burnt_blob_transaction_fees)
    else
      extended_out_json
    end
  end
end
