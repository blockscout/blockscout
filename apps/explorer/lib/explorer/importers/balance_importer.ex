defmodule Explorer.BalanceImporter do
  @moduledoc "Imports a balance for a given address."

  alias Explorer.{Chain, Ethereum}

  def import(hash) do
    encoded_balance = Ethereum.download_balance(hash)

    persist_balance(hash, encoded_balance)
  end

  defp persist_balance(hash, encoded_balance) when is_binary(hash) do
    decoded_balance = Ethereum.decode_integer_field(encoded_balance)

    Chain.update_balance(hash, decoded_balance)
  end
end
