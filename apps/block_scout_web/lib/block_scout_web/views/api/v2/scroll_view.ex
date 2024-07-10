defmodule BlockScoutWeb.API.V2.ScrollView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Transaction

  @doc """
    Extends the json output with a sub-map containing information related Scroll.
  """
  @spec extend_transaction_json_response(map(), map()) :: map()
  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    out_json
    |> add_optional_transaction_field(transaction, :l1_fee)
  end

  defp add_optional_transaction_field(out_json, transaction, field) do
    case Map.get(transaction, field) do
      nil -> out_json
      value -> Map.put(out_json, Atom.to_string(field), value)
    end
  end
end
