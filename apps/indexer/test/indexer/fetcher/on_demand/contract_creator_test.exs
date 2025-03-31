defmodule Indexer.Fetcher.OnDemand.ContractCreatorTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Address
  alias Explorer.Utility.MissingBlockRange
  alias Indexer.Fetcher.OnDemand.ContractCreator, as: ContractCreatorOnDemand

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    start_supervised!({ContractCreatorOnDemand, name: ContractCreatorOnDemand})

    :ok
  end

  describe "start_link/1" do
    test "starts the GenServer and initializes the ETS table" do
      assert :ets.info(:contract_creator_lookup) != :undefined
    end
  end

  describe "trigger_fetch/1" do
    test "does nothing if the address has no contract code" do
      address = %Address{contract_code: nil}
      assert :ignore = ContractCreatorOnDemand.trigger_fetch(address)
    end

    test "does nothing if the address already has a creator hash from regular transaction" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      insert(:transaction, %{created_contract_address_hash: contract_address.hash})
      |> with_block()

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction])
               )
    end

    test "does nothing if the address already has a creator hash from internal transaction" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :internal_transaction_create,
        transaction: transaction,
        index: 0,
        created_contract_address: contract_address,
        created_contract_code: "0x1234",
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_internal_transaction])
               )
    end

    test "does nothing if creation transaction block number lookup is in progress" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      :ets.insert(:contract_creator_lookup, {to_string(contract_address.hash), :in_progress})

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction, :contract_creation_internal_transaction])
               )
    end

    test "does nothing if creation transaction block number lookup, but indexing of corresponding block is not yet started" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      :ets.insert(:contract_creator_lookup, {to_string(contract_address.hash), 12345})

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction, :contract_creation_internal_transaction])
               )
    end

    test "does nothing if creation transaction block number lookup, but indexing of corresponding block is in progress" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      :ets.insert(:contract_creator_lookup, {to_string(contract_address.hash), 12345})

      :ets.insert(
        :contract_creator_lookup,
        {"pending_blocks", [%{block_number: 12345, address_hash_string: to_string(contract_address.hash)}]}
      )

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction, :contract_creation_internal_transaction])
               )
    end

    test "initiates fetch if address has contract code but no creator hash (target block is right from the middle)" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      now = Timex.now()

      Enum.each(0..4, fn i ->
        insert(:block, number: i, timestamp: Timex.shift(now, minutes: -i))
      end)

      Explorer.Chain.Cache.BlockNumber.get_max()

      contract_address_hash = to_string(contract_address.hash)

      EthereumJSONRPC.Mox
      |> eth_get_transaction_count_mock(contract_address_hash, "0x2", "0x0")
      |> eth_get_transaction_count_mock(contract_address_hash, "0x3", "0x1")

      assert :ok =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction, :contract_creation_internal_transaction])
               )

      :timer.sleep(100)

      assert :ets.lookup(:contract_creator_lookup, contract_address_hash) == [{contract_address_hash, :in_progress}]

      :timer.sleep(200)

      assert [%{from_number: 3, to_number: 3, priority: 1}] = Repo.all(MissingBlockRange)

      assert :ets.lookup(:contract_creator_lookup, "pending_blocks") == [
               {"pending_blocks", [%{block_number: 3, address_hash_string: contract_address_hash}]}
             ]
    end
  end

  test "initiates fetch if address has contract code but no creator hash (target block is in the middle)" do
    contract_address =
      insert(:address, contract_code: "0x1234")

    now = Timex.now()

    Enum.each(0..4, fn i ->
      insert(:block, number: i, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    EthereumJSONRPC.Mox
    |> eth_get_transaction_count_mock(contract_address_hash, "0x2", "0x1")
    |> eth_get_transaction_count_mock(contract_address_hash, "0x1", "0x0")

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction, :contract_creation_internal_transaction])
             )

    :timer.sleep(100)

    assert :ets.lookup(:contract_creator_lookup, contract_address_hash) == [{contract_address_hash, :in_progress}]

    :timer.sleep(200)

    assert [%{from_number: 2, to_number: 2, priority: 1}] = Repo.all(MissingBlockRange)

    assert :ets.lookup(:contract_creator_lookup, "pending_blocks") == [
             {"pending_blocks", [%{block_number: 2, address_hash_string: contract_address_hash}]}
           ]
  end

  test "initiates fetch if address has contract code but no creator hash (target block is left from the middle)" do
    contract_address =
      insert(:address, contract_code: "0x1234")

    now = Timex.now()

    Enum.each(0..4, fn i ->
      insert(:block, number: i, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    EthereumJSONRPC.Mox
    |> eth_get_transaction_count_mock(contract_address_hash, "0x2", "0x1")
    |> eth_get_transaction_count_mock(contract_address_hash, "0x1", "0x1")
    |> eth_get_transaction_count_mock(contract_address_hash, "0x0", "0x0")

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction, :contract_creation_internal_transaction])
             )

    :timer.sleep(100)

    assert :ets.lookup(:contract_creator_lookup, contract_address_hash) == [{contract_address_hash, :in_progress}]

    :timer.sleep(200)

    assert [%{from_number: 1, to_number: 1, priority: 1}] = Repo.all(MissingBlockRange)

    assert :ets.lookup(:contract_creator_lookup, "pending_blocks") == [
             {"pending_blocks", [%{block_number: 1, address_hash_string: contract_address_hash}]}
           ]
  end

  defp eth_get_transaction_count_mock(mox, contract_address_hash, block_number, nonce) do
    mox
    |> expect(:json_rpc, fn %{
                              id: _id,
                              jsonrpc: "2.0",
                              method: "eth_getTransactionCount",
                              params: [^contract_address_hash, ^block_number]
                            },
                            _ ->
      {:ok, nonce}
    end)
  end
end
