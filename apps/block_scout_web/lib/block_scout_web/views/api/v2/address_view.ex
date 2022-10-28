defmodule BlockScoutWeb.API.V2.AddressView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{ApiView, Helper, TokenView}
  alias BlockScoutWeb.API.V2.Helper

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("address.json", %{address: address, conn: conn}) do
    prepare_address(address, conn)
  end

  def render("token_balances.json", %{token_balances: token_balances}) do
    Enum.map(token_balances, &prepare_token_balance/1)
  end

  def prepare_address(address, conn \\ nil) do
    Helper.address_with_info(conn, address, address.hash)
  end

  def prepare_token_balance({token_balance, token}) do
    %{
      "value" => token_balance.value,
      "token" => TokenView.render("token.json", %{token: token}),
      "token_id" => token_balance.token_id
    }
  end
end
