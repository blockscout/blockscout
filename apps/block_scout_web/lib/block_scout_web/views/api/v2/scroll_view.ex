defmodule BlockScoutWeb.API.V2.ScrollView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.TransactionView
  alias Explorer.Chain.Scroll.L1FeeParam
  alias Explorer.Chain.{Data, Transaction}

  @api_true [api?: true]

  @doc """
    Extends the json output with a sub-map containing information related Scroll.

    ## Parameters
    - `out_json`: A map defining output json which will be extended.
    - `transaction`: Transaction structure containing Scroll related data

    ## Returns
    - A map extended with the data related to Scroll rollup.
  """
  @spec extend_transaction_json_response(map(), %{
          :__struct__ => Transaction,
          :block_number => non_neg_integer(),
          :index => non_neg_integer(),
          :input => Data.t(),
          optional(any()) => any()
        }) :: map()
  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    config = Application.get_all_env(:explorer)[L1FeeParam]

    l1_fee_scalar = get_param(:scalar, transaction, config)
    l1_fee_commit_scalar = get_param(:commit_scalar, transaction, config)
    l1_fee_blob_scalar = get_param(:blob_scalar, transaction, config)
    l1_fee_overhead = get_param(:overhead, transaction, config)
    l1_base_fee = get_param(:l1_base_fee, transaction, config)
    l1_blob_base_fee = get_param(:l1_blob_base_fee, transaction, config)

    l1_gas_used = L1FeeParam.l1_gas_used(transaction, l1_fee_overhead)

    l2_fee =
      transaction
      |> Transaction.l2_fee(:wei)
      |> TransactionView.format_fee()

    out_json
    |> add_optional_transaction_field(transaction, :l1_fee)
    |> Map.put("l1_fee_scalar", l1_fee_scalar)
    |> Map.put("l1_fee_commit_scalar", l1_fee_commit_scalar)
    |> Map.put("l1_fee_blob_scalar", l1_fee_blob_scalar)
    |> Map.put("l1_fee_overhead", l1_fee_overhead)
    |> Map.put("l1_base_fee", l1_base_fee)
    |> Map.put("l1_blob_base_fee", l1_blob_base_fee)
    |> Map.put("l1_gas_used", l1_gas_used)
    |> Map.put("l2_fee", l2_fee)
  end

  defp add_optional_transaction_field(out_json, transaction, field) do
    case Map.get(transaction, field) do
      nil -> out_json
      value -> Map.put(out_json, Atom.to_string(field), value)
    end
  end

  defp get_param(name, transaction, config) do
    name_init = :"#{name}#{:_init}"

    case L1FeeParam.get_for_transaction(name, transaction, @api_true) do
      nil -> config[name_init]
      value -> value
    end
  end
end
