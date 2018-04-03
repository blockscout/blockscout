defmodule Explorer.BalanceImporter do
  @moduledoc "Imports a balance for a given address."

  alias Explorer.Address.Service, as: Address
  alias Explorer.Ethereum

  def import(hash) do
    hash
    |> Ethereum.download_balance()
    |> persist_balance(hash)
  end

  defp persist_balance(balance, hash) do
    balance
    |> Ethereum.decode_integer_field()
    |> Address.update_balance(hash)
  end
end
