defmodule BlockScoutWeb.API.V2.CeloView do
  require Logger

  alias BlockScoutWeb.API.V2.TokenView
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.Transaction

  def extend_transaction_json_response(out_json, %Transaction{gas_token: %NotLoaded{}}), do: out_json

  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    out_json
    |> Map.put(
      "gas_token",
      render_token(transaction)
    )
  end

  defp render_token(%Transaction{gas_token_contract_address: nil}), do: nil

  defp render_token(%Transaction{gas_token: nil} = transaction) do
    Logger.error(
      "Transaction #{transaction.hash} has a gas token contract address '#{transaction.gas_token_contract_address}' but no associated token found in the database"
    )

    nil
  end

  defp render_token(%Transaction{} = transaction) do
    TokenView.render("token.json", %{
      token: transaction.gas_token,
      contract_address_hash: transaction.gas_token_contract_address
    })
  end
end
