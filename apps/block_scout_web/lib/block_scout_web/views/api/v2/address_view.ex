defmodule BlockScoutWeb.API.V2.AddressView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.AddressView
  alias BlockScoutWeb.API.V2.{ApiView, Helper, TokenView}
  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.ExchangeRates.Token

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
    base_info = Helper.address_with_info(conn, address, address.hash)
    is_proxy = AddressView.smart_contract_is_proxy?(address)

    {implementation_address, implementation_name} =
      with true <- is_proxy,
           {address, name} <- SmartContract.get_implementation_address_hash(address.smart_contract),
           false <- is_nil(address),
           {:ok, address_hash} <- Chain.string_to_address_hash(address),
           checksummed_address <- Address.checksum(address_hash) do
        {checksummed_address, name}
      else
        _ ->
          {nil, nil}
      end

    balance = address.fetched_coin_balance && address.fetched_coin_balance.value
    exchange_rate = (Market.get_exchange_rate(Explorer.coin()) || Token.null()).usd_value

    creator_hash = AddressView.from_address_hash(address)
    creation_tx = creator_hash && AddressView.transaction_hash(address)
    token = address.token && TokenView.render("token.json", %{token: Market.add_price(address.token)})

    Map.merge(base_info, %{
      "creator_address_hash" => creator_hash && Address.checksum(creator_hash),
      "creation_tx_hash" => creation_tx,
      "token" => token,
      "coin_balance" => balance,
      "exchange_rate" => exchange_rate,
      "implementation_name" => implementation_name,
      "implementation_address" => implementation_address,
      "block_number_balance_updated_at" => address.fetched_coin_balance_block_number
    })
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
