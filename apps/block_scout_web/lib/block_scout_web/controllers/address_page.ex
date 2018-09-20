defmodule AddressPage do
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token

  def build_params(%{address: address} = params) do
    default_params = %{
      exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
      transaction_count: transaction_count(address)
    }

    Map.merge(default_params, params)
  end

  defp transaction_count(%Address{} = address) do
    Chain.address_to_transaction_count(address)
  end
end
