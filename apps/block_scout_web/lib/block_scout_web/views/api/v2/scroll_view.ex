defmodule BlockScoutWeb.API.V2.ScrollView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.TransactionView
  alias Explorer.Chain.Scroll.L1FeeParam
  alias Explorer.Chain.Transaction

  @api_true [api?: true]

  @doc """
    Extends the json output with a sub-map containing information related Scroll.
  """
  @spec extend_transaction_json_response(map(), map()) :: map()
  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    l1_fee_scalar = L1FeeParam.get_for_transaction(:scalar, transaction, @api_true)
    l1_fee_overhead = L1FeeParam.get_for_transaction(:overhead, transaction, @api_true)
    l1_gas_used = L1FeeParam.l1_gas_used(transaction, l1_fee_overhead)

    l2_fee =
      transaction
      |> Transaction.l2_fee(:wei)
      |> TransactionView.format_fee()

    out_json
    |> add_optional_transaction_field(transaction, :l1_fee)
    |> Map.put("l1_fee_scalar", l1_fee_scalar)
    |> Map.put("l1_fee_overhead", l1_fee_overhead)
    |> Map.put("l1_gas_used", l1_gas_used)
    |> Map.put("l2_fee", l2_fee)
  end

  defp add_optional_transaction_field(out_json, transaction, field) do
    case Map.get(transaction, field) do
      nil -> out_json
      value -> Map.put(out_json, Atom.to_string(field), value)
    end
  end
end
