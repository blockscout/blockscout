defmodule Indexer.Address.TokenBalances do
  @moduledoc """
  Extracts `Explorer.Address.TokenBalance` params from other schema's params.
  """

  def params_set(%{} = import_options) do
    Enum.reduce(import_options, MapSet.new(), &reducer/2)
  end

  defp reducer({:token_transfers_params, token_transfers_params}, initial) when is_list(token_transfers_params) do
    Enum.reduce(token_transfers_params, initial, fn %{
                                                      block_number: block_number,
                                                      from_address_hash: from_address_hash,
                                                      to_address_hash: to_address_hash,
                                                      token_contract_address_hash: token_contract_address_hash
                                                    },
                                                    acc
                                                    when is_integer(block_number) and is_binary(from_address_hash) and
                                                           is_binary(to_address_hash) and
                                                           is_binary(token_contract_address_hash) ->
      acc
      |> MapSet.put(%{
        address_hash: from_address_hash,
        token_contract_address_hash: token_contract_address_hash,
        block_number: block_number
      })
      |> MapSet.put(%{
        address_hash: to_address_hash,
        token_contract_address_hash: token_contract_address_hash,
        block_number: block_number
      })
      |> MapSet.put(%{
        address_hash: token_contract_address_hash,
        token_contract_address_hash: token_contract_address_hash,
        block_number: block_number
      })
    end)
  end
end
