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

  def render("coin_balance.json", %{coin_balance: coin_balance}) do
    prepare_coin_balance_history_entry(coin_balance)
  end

  def render("coin_balances.json", %{coin_balances: coin_balances, next_page_params: next_page_params}) do
    %{"items" => Enum.map(coin_balances, &prepare_coin_balance_history_entry/1), "next_page_params" => next_page_params}
  end

  def render("coin_balances_by_day.json", %{coin_balances_by_day: coin_balances_by_day}) do
    Enum.map(coin_balances_by_day, &prepare_coin_balance_history_by_day_entry/1)
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

  def prepare_coin_balance_history_entry(coin_balance) do
    %{
      "transaction_hash" => coin_balance.transaction_hash,
      "block_number" => coin_balance.block_number,
      "delta" => coin_balance.delta,
      "value" => coin_balance.value,
      "block_timestamp" => coin_balance.block_timestamp
    }
  end

  def prepare_coin_balance_history_by_day_entry(coin_balance_by_day) do
    %{
      "date" => coin_balance_by_day.date,
      "value" => coin_balance_by_day.value
    }
  end
end
