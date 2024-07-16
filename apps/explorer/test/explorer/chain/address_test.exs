defmodule Explorer.Chain.AddressTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Address
  alias Explorer.Repo

  setup :verify_on_exit!

  describe "changeset/2" do
    test "with valid attributes" do
      params = params_for(:address)
      changeset = Address.changeset(%Address{}, params)
      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = Address.changeset(%Address{}, %{dog: "woodstock"})
      refute changeset.valid?
    end
  end

  describe "count_with_fetched_coin_balance/0" do
    test "returns the number of addresses with fetched_coin_balance greater than 0" do
      insert(:address, fetched_coin_balance: 0)
      insert(:address, fetched_coin_balance: 1)
      insert(:address, fetched_coin_balance: 2)

      assert Repo.one(Address.count_with_fetched_coin_balance()) == 2
    end
  end

  describe "Phoenix.HTML.Safe.to_iodata/1" do
    setup do
      Application.put_env(:explorer, :checksum_function, :eth)

      :ok
    end

    defp str(value) do
      to_string(insert(:address, hash: value))
    end

    test "returns the checksum formatted address" do
      assert str("0xdf9aac76b722b08511a4c561607a9bf3afa62e49") == "0xDF9AaC76b722B08511A4C561607A9bf3AfA62E49"
      assert str("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed") == "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
      assert str("0xfb6916095ca1df60bb79ce92ce3ea74c37c5d359") == "0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359"
      assert str("0xdbf03b407c01e7cd3cbea99509d93f8dddc8c6fb") == "0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB"
      assert str("0xd1220a0cf47c7b9be7a2e6ba89f429762e7b9adb") == "0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb"
    end

    test "returns the checksum rsk formatted address" do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok, "30"}
      end)

      Application.put_env(:explorer, :checksum_function, :rsk)

      assert str("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed") == "0x5aaEB6053f3e94c9b9a09f33669435E7ef1bEAeD"
      assert str("0xfb6916095ca1df60bb79ce92ce3ea74c37c5d359") == "0xFb6916095cA1Df60bb79ce92cE3EA74c37c5d359"
      assert str("0xdbf03b407c01e7cd3cbea99509d93f8dddc8c6fb") == "0xDBF03B407c01E7CD3cBea99509D93F8Dddc8C6FB"
      assert str("0xd1220a0cf47c7b9be7a2e6ba89f429762e7b9adb") == "0xD1220A0Cf47c7B9BE7a2e6ba89F429762E7B9adB"
    end
  end

  describe "list_top_addresses/0" do
    test "without addresses with balance > 0" do
      insert(:address, fetched_coin_balance: 0)
      assert [] = Address.list_top_addresses()
    end

    test "with top addresses in order" do
      address_hashes =
        4..1
        |> Enum.map(&insert(:address, fetched_coin_balance: &1))
        |> Enum.map(& &1.hash)

      assert address_hashes ==
               Address.list_top_addresses()
               |> Enum.map(fn {address, _transaction_count} -> address end)
               |> Enum.map(& &1.hash)
    end

    # flaky test
    # test "with top addresses in order with matching value" do
    #   test_hashes =
    #     4..0
    #     |> Enum.map(&Explorer.Chain.Hash.cast(Explorer.Chain.Hash.Address, &1))
    #     |> Enum.map(&elem(&1, 1))

    #   tail =
    #     4..1
    #     |> Enum.map(&insert(:address, fetched_coin_balance: &1, hash: Enum.fetch!(test_hashes, &1 - 1)))
    #     |> Enum.map(& &1.hash)

    #   first_result_hash =
    #     :address
    #     |> insert(fetched_coin_balance: 4, hash: Enum.fetch!(test_hashes, 4))
    #     |> Map.fetch!(:hash)

    #   assert [first_result_hash | tail] ==
    #            Address.list_top_addresses()
    #            |> Enum.map(fn {address, _transaction_count} -> address end)
    #            |> Enum.map(& &1.hash)
    # end

    # flaky test
    # test "paginates addresses" do
    #   test_hashes =
    #     4..0
    #     |> Enum.map(&Explorer.Chain.Hash.cast(Explorer.Chain.Hash.Address, &1))
    #     |> Enum.map(&elem(&1, 1))

    #   result =
    #     4..1
    #     |> Enum.map(&insert(:address, fetched_coin_balance: &1, hash: Enum.fetch!(test_hashes, &1 - 1)))
    #     |> Enum.map(& &1.hash)

    #   options = [paging_options: %PagingOptions{page_size: 1}]

    #   [{top_address, _}] = Chain.list_top_addresses(options)
    #   assert top_address.hash == List.first(result)

    #   tail_options = [
    #     paging_options: %PagingOptions{key: {top_address.fetched_coin_balance.value, top_address.hash}, page_size: 3}
    #   ]

    #   tail_result = tail_options |> Address.list_top_addresses() |> Enum.map(fn {address, _} -> address.hash end)

    #   [_ | expected_tail] = result

    #   assert tail_result == expected_tail
    # end
  end
end
