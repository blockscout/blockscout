defmodule Indexer.Address.TokenBalances do
  @moduledoc """
  Extracts `Explorer.Address.TokenBalance` params from other schema's params.
  """

  def params_set(%{} = import_options) do
    Enum.reduce(import_options, MapSet.new(), &reducer/2)
  end

  defp reducer({:token_transfers_params, token_transfers_params}, initial) when is_list(token_transfers_params) do
    token_transfers_params
    |> ignore_burn_address_transfers_for_token_erc_721
    |> Enum.reduce(initial, fn %{
                                 block_number: block_number,
                                 from_address_hash: from_address_hash,
                                 to_address_hash: to_address_hash,
                                 token_contract_address_hash: token_contract_address_hash
                               },
                               acc
                               when is_integer(block_number) and is_binary(from_address_hash) and
                                      is_binary(to_address_hash) and is_binary(token_contract_address_hash) ->
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

  defp ignore_burn_address_transfers_for_token_erc_721(token_transfers_params) do
    Enum.filter(token_transfers_params, &do_filter_burn_address/1)
  end

  def do_filter_burn_address(%{from_address_hash: "0x0000000000000000000000000000000000000000", token_type: "ERC-721"}) do
    false
  end

  def do_filter_burn_address(%{to_address_hash: "0x0000000000000000000000000000000000000000", token_type: "ERC-721"}) do
    false
  end

  def do_filter_burn_address(_token_balance_param) do
    true
  end
end
