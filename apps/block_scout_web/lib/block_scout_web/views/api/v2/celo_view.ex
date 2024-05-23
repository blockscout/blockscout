defmodule BlockScoutWeb.API.V2.CeloView do
  require Logger

  alias BlockScoutWeb.API.V2.TokenView
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.Transaction

  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    token_json =
      case {
        Map.get(transaction, :gas_token_contract_address),
        Map.get(transaction, :gas_token)
      } do
        # todo: this clause is redundant, consider removing it
        {_, %NotLoaded{}} ->
          nil

        {nil, _} ->
          nil

        {gas_token_contract_address, gas_token} ->
          if is_nil(gas_token) do
            Logger.error(fn ->
              [
                "Transaction #{transaction.hash} has a ",
                "gas token contract address #{gas_token_contract_address} ",
                "but no associated token found in the database"
              ]
            end)
          end

          TokenView.render("token.json", %{
            token: gas_token,
            contract_address_hash: gas_token_contract_address
          })
      end

    Map.put(out_json, "gas_token", token_json)
  end
end
