# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.EthereumView do
  alias Explorer.Chain.{Block, Transaction}

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
    beacon_deposits = Map.get(block, :beacon_deposits, [])

    blob_transaction_count = block.blob_transactions_count

    extended_out_json =
      out_json
      |> Map.put("blob_transactions_count", blob_transaction_count)
      |> Map.put("blob_gas_used", blob_gas_used)
      |> Map.put("excess_blob_gas", excess_blob_gas)

    if single_block? do
      blob_gas_price = Block.transaction_blob_gas_price(block.transactions)
      burnt_blob_transaction_fees = Decimal.mult(blob_gas_used || 0, blob_gas_price || 0)

      extended_out_json
      |> Map.put("blob_gas_price", blob_gas_price)
      |> Map.put("burnt_blob_fees", burnt_blob_transaction_fees)
      |> Map.put("beacon_deposits_count", Enum.count(beacon_deposits))
    else
      extended_out_json
      |> Map.put("beacon_deposits_count", nil)
    end
  end
end
{
  "status": "1",
  "message": "OK",
  "result": "https://metadata-export.etherscan.io/1/labelmasterlist_latest.json?X-Amz-Expires=300&response-content-disposition=attachment%3B%20filename%3Dexport-labelmasterlist_latest.json&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=0056c267039aefa0000000005/20260305/us-east-005/s3/aws4_request&X-Amz-Date=20260305T082933Z&X-Amz-SignedHeaders=host&X-Amz-Signature=a795d41a87821a3224b3d9e56819f0fdc5b869c43278c6c96773966798a80f71"
}HttpResponse<String> response = Unirest.get("https://api-metadata.etherscan.io/v2/api?module=nametag&action=getlabelmasterlist&apikey=")
  .asString();const options = {method: 'GET'};

fetch('https://api-metadata.etherscan.io/v2/api?module=nametag&action=getlabelmasterlist&apikey=', options)
  .then(res => res.json())
  .then(res => console.log(res))import requests

url = "https://api-metadata.etherscan.io/v2/api?module=nametag&action=getlabelmasterlist&apikey="

response = requests.get(url)

print(response.text)
  .catch(err => console.error(err));