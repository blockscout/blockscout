defmodule Explorer.Etherscan.Contracts do
  @moduledoc """
  This module contains functions for working with contracts, as they pertain to the
  `Explorer.Etherscan` context.

  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash, ProxyContract, SmartContract}

  @spec address_hash_to_address_with_source_code(Hash.Address.t()) :: Address.t() | nil
  def address_hash_to_address_with_source_code(address_hash) do
    result =
      case Repo.replica().get(Address, address_hash) do
        nil ->
          nil

        address ->
          address_with_smart_contract =
            Repo.replica().preload(address, [
              :smart_contract,
              :decompiled_smart_contracts,
              :smart_contract_additional_sources
            ])

          if address_with_smart_contract.smart_contract do
            formatted_code = format_source_code_output(address_with_smart_contract.smart_contract)

            %{
              address_with_smart_contract
              | smart_contract: %{address_with_smart_contract.smart_contract | contract_source_code: formatted_code}
            }
          else
            address_verified_twin_contract =
              Chain.get_minimal_proxy_template(address_hash) ||
                Chain.get_address_verified_twin_contract(address_hash).verified_contract

            if address_verified_twin_contract do
              formatted_code = format_source_code_output(address_verified_twin_contract)

              %{
                address_with_smart_contract
                | smart_contract: %{address_verified_twin_contract | contract_source_code: formatted_code}
              }
            else
              address_with_smart_contract
            end
          end
      end

    result
    |> append_proxy_info()
  end

  def get_proxied_address(address_hash) do
    query =
      from(contract in ProxyContract,
        where: contract.proxy_address == ^address_hash
      )

    query
    |> Repo.replica().one()
    |> case do
      nil -> {:error, :not_found}
      proxy_contract -> {:ok, proxy_contract.implementation_address}
    end
  end

  def append_proxy_info(%Address{smart_contract: smart_contract} = address) when not is_nil(smart_contract) do
    updated_smart_contract =
      if Chain.proxy_contract?(address.hash, smart_contract.abi) do
        smart_contract
        |> Map.put(:is_proxy, true)
        |> Map.put(
          :implementation_address_hash_string,
          address.hash
          |> Chain.get_implementation_address_hash(smart_contract.abi)
          |> Tuple.to_list()
          |> List.first()
        )
      else
        smart_contract
        |> Map.put(:is_proxy, false)
      end

    address
    |> Map.put(:smart_contract, updated_smart_contract)
  end

  def append_proxy_info(address), do: address

  def list_verified_contracts(limit, offset) do
    query =
      from(
        smart_contract in SmartContract,
        order_by: [asc: smart_contract.inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:address]
      )

    query
    |> Repo.replica().all()
    |> Enum.map(fn smart_contract ->
      Map.put(smart_contract.address, :smart_contract, smart_contract)
    end)
  end

  def list_decompiled_contracts(limit, offset, not_decompiled_with_version \\ nil) do
    query =
      from(
        address in Address,
        where: address.contract_code != <<>>,
        where: not is_nil(address.contract_code),
        where: address.decompiled == true,
        limit: ^limit,
        offset: ^offset,
        order_by: [asc: address.inserted_at],
        preload: [:smart_contract]
      )

    query
    |> reject_decompiled_with_version(not_decompiled_with_version)
    |> Repo.replica().all()
  end

  def list_unordered_unverified_contracts(limit, offset) do
    query =
      from(
        address in Address,
        where: address.contract_code != <<>>,
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

  def list_unordered_not_decompiled_contracts(limit, offset) do
    query =
      from(
        address in Address,
        where: fragment("? IS NOT TRUE", address.verified),
        where: fragment("? IS NOT TRUE", address.decompiled),
        where: address.contract_code != <<>>,
        where: not is_nil(address.contract_code),
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
        where: address.contract_code == <<>>,
        preload: [:smart_contract, :decompiled_smart_contracts],
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

  defp reject_decompiled_with_version(query, nil), do: query

  defp reject_decompiled_with_version(query, reject_version) do
    from(
      address in query,
      left_join: decompiled_smart_contract in assoc(address, :decompiled_smart_contracts),
      on: decompiled_smart_contract.decompiler_version == ^reject_version,
      where: is_nil(decompiled_smart_contract.address_hash)
    )
  end
end
