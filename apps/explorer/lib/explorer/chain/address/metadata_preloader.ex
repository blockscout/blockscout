# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Address.MetadataPreloader do
  @moduledoc """
  Module responsible for preloading metadata (from BENS, Metadata microservices) to addresses.
  """
  alias Ecto.Association.NotLoaded
  alias Explorer.MicroserviceInterfaces.{BENS, Metadata}

  alias Explorer.Chain.{
    Address,
    Address.CurrentTokenBalance,
    Beacon.Deposit,
    Block,
    InternalTransaction,
    Log,
    Token.Instance,
    TokenTransfer,
    Transaction,
    Withdrawal
  }

  alias Explorer.Stats.HotSmartContracts

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

  @typedoc """
  Kind of entity being preloaded, used to pick the `DISABLE_*_BENS_PRELOAD` flag
  that applies to it. `:any` means that no flag applies.
  """
  @type entity_kind :: :any | :blocks | :token_transfers | :transactions

  @typedoc """
  Field a microservice preload writes to: `:ens_domain_name` is served by BENS,
  `:metadata` by the Metadata microservice.
  """
  @type meta_field :: :ens_domain_name | :metadata

  @all_meta_fields [:ens_domain_name, :metadata]

  # Backstop for the concurrent microservice requests. Both BENS and Metadata
  # enforce their own receive timeout, so this only fires if a request hangs
  # outside of it.
  @concurrent_preload_timeout :timer.seconds(10)

  @doc """
  Preloads ENS names and metadata to supported entities, querying the BENS and
  Metadata microservices concurrently.

  Both microservices are asked about the same set of address hashes, so their
  requests are independent and there is nothing to gain from issuing them one
  after another: sequentially the entity waits for the sum of both round trips,
  concurrently only for the slower one.

  `entity_kind` selects the `DISABLE_*_BENS_PRELOAD` flag that applies to the
  input. The metadata preload is not flag-gated.
  """
  @spec maybe_preload_ens_and_metadata(supported_input(), entity_kind()) :: supported_input()
  def maybe_preload_ens_and_metadata(input, entity_kind \\ :any) do
    fields =
      if BENS.ens_preload_disabled?(entity_kind),
        do: @all_meta_fields -- [:ens_domain_name],
        else: @all_meta_fields

    maybe_preload_selected_meta(input, fields)
  end

  @doc """
  Preloads only the requested `fields` to supported entities, querying the
  microservices that serve them concurrently.

  Use this where the caller decides per request which preloads to pay for, such
  as the `preload_ens` and `preload_metadata` parameters of the transaction
  preview endpoint. Unlike `maybe_preload_ens_and_metadata/2`, no
  `DISABLE_*_BENS_PRELOAD` flag is consulted: those flags exist to keep the
  latency out of list endpoints that always preload, whereas here nothing is
  requested unless the caller asks for it.
  """
  @spec maybe_preload_selected_meta(supported_input(), [meta_field()]) :: supported_input()
  def maybe_preload_selected_meta(input, fields)

  def maybe_preload_selected_meta(input, []), do: input

  def maybe_preload_selected_meta(nil, _fields), do: nil

  def maybe_preload_selected_meta(items, fields) when is_list(items) do
    preload_selected_meta(items, fields)
  end

  def maybe_preload_selected_meta(item, fields) do
    [item_with_meta] = preload_selected_meta([item], fields)
    item_with_meta
  end

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
  Preloads ENS name to Block.t()
  """
  @spec preload_ens_to_block(Block.t()) :: Block.t()
  def preload_ens_to_block(block) do
    [block_with_ens] = preload_ens_to_list([block])
    block_with_ens
  end

  @doc """
  Preloads ENS names to list of supported entities
  """
  @spec preload_ens_to_list([supported_types]) :: [supported_types]
  def preload_ens_to_list(items) do
    address_hash_strings = address_hash_strings(items)

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
    address_hash_strings = address_hash_strings(items)

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
  Preloads metadata to Block.t()
  """
  @spec preload_metadata_to_block(Block.t()) :: Block.t()
  def preload_metadata_to_block(block) do
    [block_with_metadata] = preload_metadata_to_list([block])
    block_with_metadata
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

  defp preload_selected_meta(items, fields) do
    case address_hash_strings(items) do
      [] ->
        items

      address_hash_strings ->
        address_hash_strings
        |> meta_fetchers(fields)
        |> fetch_meta()
        |> Enum.reduce(items, fn {field, meta}, acc -> put_meta_to_items(acc, meta, field) end)
    end
  end

  defp address_hash_strings(items) do
    items
    |> Enum.flat_map(&item_to_address_hash_strings/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp meta_fetchers(address_hash_strings, fields) do
    [
      {:ens_domain_name, BENS.enabled?(), fn -> ens_names(address_hash_strings) end},
      {:metadata, Metadata.enabled?(), fn -> metadata_tags(address_hash_strings) end}
    ]
    |> Enum.filter(fn {field, enabled?, _fetcher} -> enabled? and field in fields end)
  end

  defp fetch_meta([]), do: []

  # A single request needs no task: running it in the caller keeps the logger
  # metadata and the stacktrace of the calling process.
  defp fetch_meta([{field, _enabled?, fetcher}]), do: fetched_meta(field, fetcher.())

  defp fetch_meta(fetchers) do
    Explorer.TaskSupervisor
    |> Task.Supervisor.async_stream_nolink(
      fetchers,
      fn {field, _enabled?, fetcher} -> {field, fetcher.()} end,
      timeout: @concurrent_preload_timeout,
      on_timeout: :kill_task,
      ordered: false
    )
    |> Enum.flat_map(fn
      {:ok, {field, result}} -> fetched_meta(field, result)
      _other -> []
    end)
  end

  defp fetched_meta(field, {:ok, meta}), do: [{field, meta || %{}}]
  defp fetched_meta(_field, _error), do: []

  defp ens_names(address_hash_strings) do
    case BENS.ens_names_batch_request(address_hash_strings) do
      {:ok, result} -> {:ok, result["names"]}
      _error -> :error
    end
  end

  defp metadata_tags(address_hash_strings) do
    case Metadata.get_addresses_tags(address_hash_strings) do
      {:ok, result} -> {:ok, result["addresses"]}
      _error -> :error
    end
  end

  defp put_meta_to_items(items, meta, field) do
    Enum.map(items, &put_meta_to_item(&1, meta, field))
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

  defp item_to_address_hash_strings(%Deposit{
         from_address_hash: from_address_hash,
         withdrawal_address_hash: withdrawal_address_hash
       }) do
    if withdrawal_address_hash do
      [to_string(withdrawal_address_hash), to_string(from_address_hash)]
    else
      [to_string(from_address_hash)]
    end
  end

  defp item_to_address_hash_strings(%HotSmartContracts{contract_address_hash: contract_address_hash}) do
    [to_string(contract_address_hash)]
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

  defp put_meta_to_item(
         %Deposit{
           from_address: from_address,
           from_address_hash: from_address_hash,
           withdrawal_address: withdrawal_address,
           withdrawal_address_hash: withdrawal_address_hash
         } = deposit,
         names,
         field_to_put_info
       ) do
    %Deposit{
      deposit
      | from_address: alter_address(from_address, from_address_hash, names, field_to_put_info),
        withdrawal_address: alter_address(withdrawal_address, withdrawal_address_hash, names, field_to_put_info)
    }
  end

  defp put_meta_to_item(
         %HotSmartContracts{contract_address_hash: contract_address_hash, contract_address: contract_address} =
           hot_contract,
         names,
         field_to_put_info
       ) do
    %HotSmartContracts{
      hot_contract
      | contract_address: alter_address(contract_address, contract_address_hash, names, field_to_put_info)
    }
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
