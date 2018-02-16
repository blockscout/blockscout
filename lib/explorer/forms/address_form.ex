defmodule Explorer.AddressForm do
  @moduledoc false

  alias Explorer.Credit
  alias Explorer.Debit

  def build(address) do
    credit = address.credit || Credit.null
    debit = address.debit || Debit.null
    balance = Decimal.sub(credit.value, debit.value)
    Map.put(address, :balance, balance)
  end
end
