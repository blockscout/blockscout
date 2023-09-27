defmodule Indexer.Transform.TokenInstances do
  @moduledoc """
    Module extracts token instances from token transfers
  """

  def params_set(%{} = import_options) do
    Enum.reduce(import_options, %{}, &reducer/2)
  end

  defp reducer({:token_transfers_params, token_transfers_params}, initial) when is_list(token_transfers_params) do
    token_transfers_params
    |> Enum.reduce(initial, fn
      %{
        block_number: block_number,
        from_address_hash: from_address_hash,
        to_address_hash: to_address_hash,
        token_contract_address_hash: token_contract_address_hash,
        token_ids: [_ | _]
      } = tt,
      acc
      when is_integer(block_number) and
             is_binary(from_address_hash) and
             is_binary(to_address_hash) and is_binary(token_contract_address_hash) ->
        transfer_to_instances(tt, acc)

      _, acc ->
        acc
    end)
    |> Map.values()
  end

  defp transfer_to_instances(
         %{
           token_type: "ERC-721" = token_type,
           to_address_hash: to_address_hash,
           token_ids: [token_id],
           token_contract_address_hash: token_contract_address_hash,
           block_number: block_number,
           log_index: log_index
         },
         acc
       ) do
    params = %{
      token_contract_address_hash: token_contract_address_hash,
      token_id: token_id,
      token_type: token_type,
      owner_address_hash: to_address_hash,
      owner_updated_at_block: block_number,
      owner_updated_at_log_index: log_index
    }

    current_key = {token_contract_address_hash, token_id}

    Map.put(
      acc,
      current_key,
      Enum.max_by(
        [
          params,
          acc[current_key] || params
        ],
        fn %{
             owner_updated_at_block: owner_updated_at_block,
             owner_updated_at_log_index: owner_updated_at_log_index
           } ->
          {owner_updated_at_block, owner_updated_at_log_index}
        end
      )
    )
  end

  defp transfer_to_instances(
         %{
           token_type: _token_type,
           token_ids: [_ | _] = token_ids,
           token_contract_address_hash: token_contract_address_hash
         },
         acc
       ) do
    Enum.reduce(token_ids, acc, fn id, sub_acc ->
      Map.put(sub_acc, {token_contract_address_hash, id}, %{
        token_contract_address_hash: token_contract_address_hash,
        token_id: id,
        token_type: "ERC-1155"
      })
    end)
  end
end
