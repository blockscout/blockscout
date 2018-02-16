defmodule Explorer.AddressForm do
  @moduledoc false

  def build(address) do
    balance = Decimal.sub(address.credit.value, address.debit.value)
    Map.put(address, :balance, balance)
  end
end
