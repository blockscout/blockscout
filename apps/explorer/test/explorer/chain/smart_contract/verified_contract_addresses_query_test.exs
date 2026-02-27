defmodule Explorer.Chain.SmartContract.VerifiedContractAddressesQueryTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.SmartContract.VerifiedContractAddressesQuery
  alias Explorer.PagingOptions

  describe "list/1" do
    test "uses default strategy and orders by smart_contract id desc when sorting is absent" do
      contracts = insert_list(4, :smart_contract)

      addresses = VerifiedContractAddressesQuery.list()

      assert Enum.map(addresses, & &1.smart_contract.id) ==
               contracts |> Enum.map(& &1.id) |> Enum.sort(:desc)
    end

    test "uses sorting strategy and pages with cursor key" do
      for balance <- 0..5 do
        address = insert(:address, fetched_coin_balance: balance, verified: true)
        insert(:smart_contract, address_hash: address.hash, address: address)
      end

      sorting = [{:asc_nulls_first, :fetched_coin_balance}]
      page_size = 3

      first_page =
        VerifiedContractAddressesQuery.list(
          sorting: sorting,
          paging_options: %PagingOptions{page_size: page_size}
        )

      cursor = List.last(first_page)

      second_page =
        VerifiedContractAddressesQuery.list(
          sorting: sorting,
          paging_options: %PagingOptions{
            page_size: page_size,
            key: %{
              fetched_coin_balance: cursor.fetched_coin_balance,
              hash: cursor.hash
            }
          }
        )

      assert Enum.map(first_page, &Decimal.to_integer(&1.fetched_coin_balance.value)) == [0, 1, 2]
      assert Enum.map(second_page, &Decimal.to_integer(&1.fetched_coin_balance.value)) == [3, 4, 5]
    end

    test "searches by contract name and address hash" do
      insert_list(3, :smart_contract)
      target_name = "very-unique-smart-contract-name-1"
      name_contract = insert(:smart_contract, name: target_name)
      hash_contract = insert(:smart_contract)

      [name_result] = VerifiedContractAddressesQuery.list(search: target_name)

      [hash_result] =
        VerifiedContractAddressesQuery.list(search: String.downcase(to_string(hash_contract.address_hash)))

      assert name_result.smart_contract.id == name_contract.id
      assert name_result.smart_contract.name == target_name

      assert hash_result.smart_contract.id == hash_contract.id
      assert hash_result.hash == hash_contract.address_hash
    end
  end
end
