defmodule BlockScoutWeb.API.V2.CeloView do
  require Logger

  alias BlockScoutWeb.API.V2.TokenView
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.Transaction

  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    case {
      Map.get(transaction, :gas_token_contract_address),
      Map.get(transaction, :gas_token)
    } do
      {_, %NotLoaded{}} ->
        out_json

      {nil, _} ->
        out_json |> add_gas_token_field(nil)

      {gas_token_contract_address, nil} ->
        Logger.error(
          "Transaction #{transaction.hash} has a gas token contract address '#{gas_token_contract_address}' but no associated token found in the database"
        )

        out_json |> add_gas_token_field(nil)

      {gas_token_contract_address, gas_token} ->
        out_json
        |> add_gas_token_field(
          TokenView.render("token.json", %{
            token: gas_token,
            contract_address_hash: gas_token_contract_address
          })
        )
    end
  end

  defp add_gas_token_field(out_json, token_json) do
    out_json
    |> Map.put(
      "gas_token",
      token_json
    )
  end
end
