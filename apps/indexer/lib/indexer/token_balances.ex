defmodule Indexer.TokenBalances do
  @moduledoc """
  Reads Token's balances using Smart Contract functions from the blockchain.
  """

  alias Explorer.Token.BalanceReader

  def fetch_token_balances_from_blockchain(token_balances) do
    result =
      token_balances
      |> Task.async_stream(&fetch_token_balance/1)
      |> Enum.map(&format_result/1)

    {:ok, result}
  end

  defp fetch_token_balance(
         %{
           token_contract_address_hash: token_contract_address_hash,
           address_hash: address_hash,
           block_number: block_number
         } = token_balance
       ) do
    token_contract_address_hash
    |> BalanceReader.get_balance_of(address_hash, block_number)
    |> set_token_balance_value(token_balance)
  end

  defp set_token_balance_value({:ok, balance}, token_balance) do
    Map.merge(token_balance, %{value: balance, value_fetched_at: DateTime.utc_now()})
  end

  defp set_token_balance_value({:error, _}, token_balance) do
    Map.merge(token_balance, %{value: nil, value_fetched_at: nil})
  end

  def format_result({_, token_balance}), do: token_balance
end
