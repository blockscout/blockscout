defmodule Indexer.Transform.Celo.TransactionGasTokens do
  @moduledoc """
  Helper functions for extracting tokens specified as gas fee currency.
  """

  @doc """
  Parses transactions and extracts tokens specified as gas fee currency.
  """
  def parse(transactions) do
    transactions
    |> Enum.reduce(
      MapSet.new(),
      fn
        %{gas_token_contract_address_hash: nil}, acc ->
          acc

        %{gas_token_contract_address_hash: address_hash}, acc ->
          MapSet.put(acc, %{
            contract_address_hash: address_hash,
            type: "ERC-20"
          })

        _, acc ->
          acc
      end
    )
    |> MapSet.to_list()
  end
end
