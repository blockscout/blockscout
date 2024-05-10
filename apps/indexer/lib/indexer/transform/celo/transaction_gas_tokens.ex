defmodule Indexer.Transform.Celo.TransactionGasTokens do
  @moduledoc """
  Helper functions for extracting tokens specified as gas fee currency.
  """

  alias Explorer.Chain.Hash

  @doc """
  Parses transactions and extracts tokens specified as gas fee currency.
  """
  @spec parse([
          %{
            optional(:gas_token_contract_address_hash) => Hash.Address.t() | nil
          }
        ]) :: [
          %{
            contract_address_hash: String.t(),
            type: String.t()
          }
        ]
  def parse(transactions) do
    if Application.get_env(:explorer, :chain_type) == :celo do
      transactions
      |> Enum.reduce(
        MapSet.new(),
        fn
          %{gas_token_contract_address_hash: address_hash}, acc when not is_nil(address_hash) ->
            MapSet.put(acc, %{
              contract_address_hash: address_hash,
              type: "ERC-20"
            })

          _, acc ->
            acc
        end
      )
      |> MapSet.to_list()
    else
      []
    end
  end
end
