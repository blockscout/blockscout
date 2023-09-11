defmodule Indexer.Transform.AddressTokenBalances do
  @moduledoc """
  Extracts `Explorer.Address.TokenBalance` params from other schema's params.
  """

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  def params_set(%{} = import_options) do
    Enum.reduce(import_options, MapSet.new(), &reducer/2)
  end

  defp reducer({:token_transfers_params, token_transfers_params}, initial) when is_list(token_transfers_params) do
    token_transfers_params
    |> ignore_burn_address_transfers_for_token_erc_721()
    |> Enum.reduce(initial, fn %{
                                 block_number: block_number,
                                 from_address_hash: from_address_hash,
                                 to_address_hash: to_address_hash,
                                 token_contract_address_hash: token_contract_address_hash,
                                 token_ids: token_ids,
                                 token_type: token_type
                               },
                               acc
                               when is_integer(block_number) and is_binary(from_address_hash) and
                                      is_binary(to_address_hash) and is_binary(token_contract_address_hash) ->
      Enum.reduce(token_ids || [nil], acc, fn id, sub_acc ->
        sub_acc
        |> add_token_balance_address(from_address_hash, token_contract_address_hash, id, token_type, block_number)
        |> add_token_balance_address(to_address_hash, token_contract_address_hash, id, token_type, block_number)
      end)
    end)
  end

  defp ignore_burn_address_transfers_for_token_erc_721(token_transfers_params) do
    Enum.filter(token_transfers_params, &do_filter_burn_address/1)
  end

  defp add_token_balance_address(map_set, unquote(burn_address_hash_string()), _, _, _, _), do: map_set

  defp add_token_balance_address(map_set, address, token_contract_address, token_id, token_type, block_number) do
    MapSet.put(map_set, %{
      address_hash: address,
      token_contract_address_hash: token_contract_address,
      block_number: block_number,
      token_id: token_id,
      token_type: token_type
    })
  end

  def do_filter_burn_address(%{to_address_hash: unquote(burn_address_hash_string()), token_type: "ERC-721"}) do
    false
  end

  def do_filter_burn_address(_token_balance_param) do
    true
  end
end
