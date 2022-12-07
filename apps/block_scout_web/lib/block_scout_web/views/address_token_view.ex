defmodule BlockScoutWeb.AddressTokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.{AddressView, ChainView}
  alias Explorer.{Chain, CustomContractsHelpers}
  alias Explorer.Chain.{Address, CurrencyHelpers, Wei}

  def circles_total_balance(address_hash) do
    circles_addresses_list = CustomContractsHelpers.get_custom_addresses_list(:circles_addresses)

    token_balances =
      address_hash
      |> Chain.fetch_last_token_balances()

    token_balances_except_bridged =
      token_balances
      |> Enum.filter(fn {token_balance, _, _} -> !token_balance.token.bridged end)

    if Enum.count(circles_addresses_list) > 0 do
      token_balances_except_bridged
      |> Enum.reduce(Decimal.new(0), fn {token_balance, _, _}, acc_balance ->
        {:ok, token_address} = Chain.hash_to_address(token_balance.address_hash)

        from_address = AddressView.from_address_hash(token_address)

        created_from_address_hash =
          if from_address,
            do: "0x" <> Base.encode16(from_address.bytes, case: :lower),
            else: nil

        if Enum.member?(circles_addresses_list, created_from_address_hash) && token_balance.token.name == "Circles" &&
             token_balance.token.symbol == "CRC" do
          Decimal.add(acc_balance, token_balance.value)
        else
          acc_balance
        end
      end)
    else
      Decimal.new(0)
    end
  end
end
