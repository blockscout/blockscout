defmodule BlockScoutWeb.API.V2.RootstockView do
  alias Explorer.Chain.Block

  def extend_block_json_response(out_json, %Block{} = block) do
    out_json
    |> add_optional_transaction_field(block, :minimum_gas_price)
    |> add_optional_transaction_field(block, :bitcoin_merged_mining_header)
    |> add_optional_transaction_field(block, :bitcoin_merged_mining_coinbase_transaction)
    |> add_optional_transaction_field(block, :bitcoin_merged_mining_merkle_proof)
    |> add_optional_transaction_field(block, :hash_for_merged_mining)
  end

  defp add_optional_transaction_field(out_json, block, field) do
    case Map.get(block, field) do
      nil -> out_json
      value -> Map.put(out_json, Atom.to_string(field), value)
    end
  end
end
