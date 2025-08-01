defmodule Explorer.Chain.Address.MetadataPreloader do
  @moduledoc """
  Module responsible for preloading metadata (from BENS, Metadata microservices) to addresses.
  """
  alias Ecto.Association.NotLoaded
  alias Explorer.MicroserviceInterfaces.{BENS, Metadata}

  alias Explorer.Chain.{
    Address,
    Address.CurrentTokenBalance,
    Block,
    InternalTransaction,
    Log,
    Token.Instance,
    TokenTransfer,
    Transaction,
    Withdrawal
  }

  @type supported_types ::
          Address.t()
          | Block.t()
          | CurrentTokenBalance.t()
          | InternalTransaction.t()
          | Log.t()
          | TokenTransfer.t()
          | Transaction.t()
          | Withdrawal.t()

  @type supported_input :: [supported_types] | supported_types

  @doc """
  Preloads ENS/metadata to supported entities
  """
  @spec maybe_preload_meta(supported_input, module(), (supported_input -> supported_input)) :: supported_input
  def maybe_preload_meta(argument, module, function \\ &preload_ens_to_list/1) do
    if module.enabled?() do
      function.(argument)
    else
      argument
    end
  end

  @doc """
  Preloads ENS name to Transaction.t()
  """
  @spec preload_ens_to_transaction(Transaction.t()) :: Transaction.t()
  def preload_ens_to_transaction(transaction) do
    [transaction_with_ens] = preload_ens_to_list([transaction])
    transaction_with_ens
  end

  @doc """
  Preloads ENS name to Address.t()
  """
  @spec preload_ens_to_address(Address.t()) :: Address.t()
  def preload_ens_to_address(address) do
    [address_with_ens] = preload_ens_to_list([address])
    address_with_ens
  end

  @doc """
  Preloads ENS names to list of supported entities
  """
  @spec preload_ens_to_list([supported_types]) :: [supported_types]
  def preload_ens_to_list(items) do
    address_hash_strings =
      items
      |> Enum.reduce([], fn item, acc ->
        item_to_address_hash_strings(item) ++ acc
      end)
      |> Enum.filter(&(&1 != ""))
      |> Enum.uniq()

    case BENS.ens_names_batch_request(address_hash_strings) do
      {:ok, result} ->
        put_ens_names(result["names"], items)

      _ ->
        items
    end
  end

  @doc """
  Preloads metadata to list of supported entities
  """
  @spec preload_metadata_to_list([supported_types]) :: [supported_types]
  def preload_metadata_to_list(items) do
    address_hash_strings =
      items
      |> Enum.flat_map(&item_to_address_hash_strings/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.uniq()

    case Metadata.get_addresses_tags(address_hash_strings) do
      {:ok, result} ->
        put_metadata(result["addresses"], items)

      _ ->
        items
    end
  end

  @doc """
  Preloads metadata to Transaction.t()
  """
  @spec preload_metadata_to_transaction(Transaction.t()) :: Transaction.t()
  def preload_metadata_to_transaction(transaction) do
    [transaction_with_metadata] = preload_metadata_to_list([transaction])
    transaction_with_metadata
  end

  @doc """
    Preload ENS info to search result, using get_address/1
  """
  @spec preload_ens_info_to_search_results(list) :: list
  def preload_ens_info_to_search_results(list) do
    Enum.map(list, fn
      %{type: "address", ens_info: ens_info} = search_result when not is_nil(ens_info) ->
        search_result

      %{type: "address"} = search_result ->
        ens_info = search_result[:address_hash] |> BENS.get_address()
        Map.put(search_result, :ens_info, ens_info)

      search_result ->
        search_result
    end)
  end

  defp item_to_address_hash_strings(nil), do: []

  defp item_to_address_hash_strings(%Transaction{
         to_address_hash: to_address_hash,
         created_contract_address_hash: created_contract_address_hash,
         from_address_hash: from_address_hash,
         token_transfers: token_transfers
       }) do
    token_transfers_addresses =
      case token_transfers do
        token_transfers_list when is_list(token_transfers_list) ->
          List.flatten(Enum.map(token_transfers_list, &item_to_address_hash_strings/1))

        _ ->
          []
      end

    ([to_address_hash, created_contract_address_hash, from_address_hash]
     |> Enum.reject(&is_nil/1)
     |> Enum.map(&to_string/1)) ++ token_transfers_addresses
  end

  defp item_to_address_hash_strings(%TokenTransfer{
         to_address_hash: to_address_hash,
         from_address_hash: from_address_hash
       }) do
    [to_string(to_address_hash), to_string(from_address_hash)]
  end

  defp item_to_address_hash_strings(%InternalTransaction{
         to_address_hash: to_address_hash,
         from_address_hash: from_address_hash
       }) do
    [to_string(to_address_hash), to_string(from_address_hash)]
  end

  defp item_to_address_hash_strings(%Log{address_hash: address_hash}) do
    [to_string(address_hash)]
  end

  defp item_to_address_hash_strings(%Withdrawal{address_hash: address_hash}) do
    [to_string(address_hash)]
  end

  defp item_to_address_hash_strings(%Block{miner_hash: miner_hash}) do
    [to_string(miner_hash)]
  end

  defp item_to_address_hash_strings(%CurrentTokenBalance{address_hash: address_hash}) do
    [to_string(address_hash)]
  end

  defp item_to_address_hash_strings(%Address{hash: hash}) do
    [to_string(hash)]
  end

  defp item_to_address_hash_strings(%Instance{owner_address_hash: owner_address_hash}) do
    [to_string(owner_address_hash)]
  end

  defp put_ens_names(names, items) do
    Enum.map(items, &put_meta_to_item(&1, names, :ens_domain_name))
  end

  defp put_metadata(names, items) do
    Enum.map(items, &put_meta_to_item(&1, names, :metadata))
  end

  defp put_meta_to_item(
         %Transaction{
           to_address_hash: to_address_hash,
           created_contract_address_hash: created_contract_address_hash,
           from_address_hash: from_address_hash
         } = transaction,
         names,
         field_to_put_info
       ) do
    token_transfers =
      case transaction.token_transfers do
        token_transfers_list when is_list(token_transfers_list) ->
          Enum.map(token_transfers_list, &put_meta_to_item(&1, names, field_to_put_info))

        other ->
          other
      end

    %Transaction{
      transaction
      | to_address: alter_address(transaction.to_address, to_address_hash, names, field_to_put_info),
        created_contract_address:
          alter_address(transaction.created_contract_address, created_contract_address_hash, names, field_to_put_info),
        from_address: alter_address(transaction.from_address, from_address_hash, names, field_to_put_info),
        token_transfers: token_transfers
    }
  end

  defp put_meta_to_item(
         %TokenTransfer{
           to_address_hash: to_address_hash,
           from_address_hash: from_address_hash
         } = tt,
         names,
         field_to_put_info
       ) do
    %TokenTransfer{
      tt
      | to_address: alter_address(tt.to_address, to_address_hash, names, field_to_put_info),
        from_address: alter_address(tt.from_address, from_address_hash, names, field_to_put_info)
    }
  end

  defp put_meta_to_item(
         %InternalTransaction{
           to_address_hash: to_address_hash,
           created_contract_address_hash: created_contract_address_hash,
           from_address_hash: from_address_hash
         } = transaction,
         names,
         field_to_put_info
       ) do
    %InternalTransaction{
      transaction
      | to_address: alter_address(transaction.to_address, to_address_hash, names, field_to_put_info),
        created_contract_address:
          alter_address(transaction.created_contract_address, created_contract_address_hash, names, field_to_put_info),
        from_address: alter_address(transaction.from_address, from_address_hash, names, field_to_put_info)
    }
  end

  defp put_meta_to_item(%Log{address_hash: address_hash} = log, names, field_to_put_info) do
    %Log{log | address: alter_address(log.address, address_hash, names, field_to_put_info)}
  end

  defp put_meta_to_item(%Withdrawal{address_hash: address_hash} = withdrawal, names, field_to_put_info) do
    %Withdrawal{withdrawal | address: alter_address(withdrawal.address, address_hash, names, field_to_put_info)}
  end

  defp put_meta_to_item(%Block{miner_hash: miner_hash} = block, names, field_to_put_info) do
    %Block{block | miner: alter_address(block.miner, miner_hash, names, field_to_put_info)}
  end

  defp put_meta_to_item(
         %CurrentTokenBalance{address_hash: address_hash} = current_token_balance,
         names,
         field_to_put_info
       ) do
    %CurrentTokenBalance{
      current_token_balance
      | address: alter_address(current_token_balance.address, address_hash, names, field_to_put_info)
    }
  end

  defp put_meta_to_item(%Address{} = address, names, field_to_put_info) do
    alter_address(address, address.hash, names, field_to_put_info)
  end

  defp put_meta_to_item(
         %Instance{owner: owner_address, owner_address_hash: owner_address_hash} = instance,
         names,
         field_to_put_info
       ) do
    %Instance{instance | owner: alter_address(owner_address, owner_address_hash, names, field_to_put_info)}
  end

  defp alter_address(address, nil, _names, _field), do: address

  defp alter_address(%NotLoaded{}, address_hash, names, field) do
    %{field => names[Address.checksum(address_hash)]}
  end

  defp alter_address(nil, address_hash, names, field) do
    %{field => names[Address.checksum(address_hash)]}
  end

  defp alter_address(%Address{} = address, address_hash, names, :ens_domain_name) do
    %Address{address | ens_domain_name: names[Address.checksum(address_hash)]}
  end

  defp alter_address(%Address{} = address, address_hash, names, :metadata) do
    %Address{address | metadata: names[Address.checksum(address_hash)]}
  end

  defp alter_address(map, address_hash, names, field) when is_map(map) do
    Map.put(map, field, names[Address.checksum(address_hash)])
  end
end
