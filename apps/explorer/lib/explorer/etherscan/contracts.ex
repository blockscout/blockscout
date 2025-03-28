defmodule Explorer.Etherscan.Contracts do
  @moduledoc """
  This module contains functions for working with contracts, as they pertain to the
  `Explorer.Etherscan` context.

  """

  import Ecto.Query,
    only: [
      from: 2,
      where: 3
    ]

  alias Explorer.Repo
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation

  @doc """
    Returns address with preloaded SmartContract and proxy info if it exists
  """
  @spec address_hash_to_address_with_source_code(Hash.Address.t()) :: Address.t() | nil
  def address_hash_to_address_with_source_code(address_hash, twin_needed? \\ true) do
    result =
      case Repo.replica().get(Address, address_hash) do
        nil ->
          nil

        address ->
          address_with_smart_contract =
            Repo.replica().preload(address, [
              [smart_contract: :smart_contract_additional_sources]
            ])

          if address_with_smart_contract.smart_contract do
            formatted_code = format_source_code_output(address_with_smart_contract.smart_contract)

            %{
              address_with_smart_contract
              | smart_contract: %{address_with_smart_contract.smart_contract | contract_source_code: formatted_code}
            }
          else
            implementation_smart_contract =
              SmartContract.single_implementation_smart_contract_from_proxy(
                %{
                  updated: %SmartContract{
                    address_hash: address_hash,
                    abi: nil
                  },
                  implementation_updated_at: nil,
                  implementation_address_fetched?: false,
                  refetch_necessity_checked?: false
                },
                [
                  {:proxy_without_abi?, true}
                ]
              )

            address_verified_bytecode_twin_contract =
              implementation_smart_contract || maybe_fetch_bytecode_twin(twin_needed?, address_hash)

            compose_address_with_smart_contract(
              address_with_smart_contract,
              address_verified_bytecode_twin_contract
            )
          end
      end

    result
    |> append_proxy_info()
  end

  defp maybe_fetch_bytecode_twin(twin_needed?, address_hash),
    do: if(twin_needed?, do: SmartContract.get_address_verified_bytecode_twin_contract(address_hash))

  defp compose_address_with_smart_contract(address_with_smart_contract, address_verified_bytecode_twin_contract) do
    if address_verified_bytecode_twin_contract do
      formatted_code = format_source_code_output(address_verified_bytecode_twin_contract)

      %{
        address_with_smart_contract
        | smart_contract: %{address_verified_bytecode_twin_contract | contract_source_code: formatted_code}
      }
    else
      address_with_smart_contract
    end
  end

  def append_proxy_info(%Address{smart_contract: smart_contract} = address) when not is_nil(smart_contract) do
    updated_smart_contract =
      if Proxy.proxy_contract?(smart_contract) do
        implementation = Implementation.get_implementation(smart_contract)

        smart_contract
        |> Map.put(:is_proxy, true)
        |> Map.put(
          :implementation_address_hash_strings,
          implementation.address_hashes
        )
      else
        smart_contract
        |> Map.put(:is_proxy, false)
      end

    address
    |> Map.put(:smart_contract, updated_smart_contract)
  end

  def append_proxy_info(address), do: address

  def list_verified_contracts(limit, offset, opts) do
    query =
      from(
        smart_contract in SmartContract,
        order_by: [asc: smart_contract.inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:address]
      )

    verified_at_start_timestamp_exist? = Map.has_key?(opts, :verified_at_start_timestamp)
    verified_at_end_timestamp_exist? = Map.has_key?(opts, :verified_at_end_timestamp)

    query_in_timestamp_range =
      cond do
        verified_at_start_timestamp_exist? && verified_at_end_timestamp_exist? ->
          query
          |> where([smart_contract], smart_contract.inserted_at >= ^opts.verified_at_start_timestamp)
          |> where([smart_contract], smart_contract.inserted_at < ^opts.verified_at_end_timestamp)

        verified_at_start_timestamp_exist? ->
          query
          |> where([smart_contract], smart_contract.inserted_at >= ^opts.verified_at_start_timestamp)

        verified_at_end_timestamp_exist? ->
          query
          |> where([smart_contract], smart_contract.inserted_at < ^opts.verified_at_end_timestamp)

        true ->
          query
      end

    query_in_timestamp_range
    |> Repo.replica().all()
    |> Enum.map(fn smart_contract ->
      Map.put(smart_contract.address, :smart_contract, smart_contract)
    end)
  end

  def list_unordered_unverified_contracts(limit, offset) do
    query =
      from(
        address in Address,
        where: address.contract_code != ^%Explorer.Chain.Data{bytes: <<>>},
        where: not is_nil(address.contract_code),
        where: fragment("? IS NOT TRUE", address.verified),
        limit: ^limit,
        offset: ^offset
      )

    query
    |> Repo.replica().all()
    |> Enum.map(fn address ->
      %{address | smart_contract: nil}
    end)
  end

  def list_empty_contracts(limit, offset) do
    query =
      from(address in Address,
        where: address.contract_code == ^%Explorer.Chain.Data{bytes: <<>>},
        preload: [:smart_contract],
        order_by: [asc: address.inserted_at],
        limit: ^limit,
        offset: ^offset
      )

    Repo.replica().all(query)
  end

  def list_contracts(limit, offset) do
    query =
      from(
        address in Address,
        where: not is_nil(address.contract_code),
        preload: [:smart_contract],
        order_by: [asc: address.inserted_at],
        limit: ^limit,
        offset: ^offset
      )

    Repo.replica().all(query)
  end

  defp format_source_code_output(smart_contract), do: smart_contract.contract_source_code
end
