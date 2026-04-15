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
        index: 1,
        created_contract_address: contract_address,
        created_contract_code: "0x1234",
        block_number: transaction.block_number,
        transaction_index: transaction.index
      )

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Address.preload_contract_creation_internal_transaction()
               )
    end

    test "does nothing if creation transaction block number lookup is in progress" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      :ets.insert(:contract_creator_lookup, {to_string(contract_address.hash), :in_progress})

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction])
                 |> Address.preload_contract_creation_internal_transaction()
               )
    end

    test "does nothing if creation transaction block number lookup, but indexing of corresponding block is not yet started" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      :ets.insert(:contract_creator_lookup, {to_string(contract_address.hash), 12345})

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction])
                 |> Address.preload_contract_creation_internal_transaction()
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
                 |> Repo.preload([:contract_creation_transaction])
                 |> Address.preload_contract_creation_internal_transaction()
               )
    end

    test "initiates fetch if address has contract code but no creator hash (target block is right from the middle)" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      now = Timex.now()

      Enum.each(0..4, fn i ->
        insert(:block, number: i, refetch_needed: i == 3, timestamp: Timex.shift(now, minutes: -i))
      end)

      Explorer.Chain.Cache.BlockNumber.get_max()

      contract_address_hash = to_string(contract_address.hash)

      EthereumJSONRPC.Mox
      |> eth_get_transaction_count_mock(contract_address_hash, "0x2", "0x0")
      |> eth_get_transaction_count_mock(contract_address_hash, "0x3", "0x1")

      assert :ok =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction])
                 |> Address.preload_contract_creation_internal_transaction()
               )

      :timer.sleep(300)

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
      insert(:block, number: i, refetch_needed: i == 2, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    EthereumJSONRPC.Mox
    |> eth_get_transaction_count_mock(contract_address_hash, "0x2", "0x1")
    |> eth_get_transaction_count_mock(contract_address_hash, "0x1", "0x0")

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction])
               |> Address.preload_contract_creation_internal_transaction()
             )

    :timer.sleep(300)

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
      insert(:block, number: i, refetch_needed: i == 1, timestamp: Timex.shift(now, minutes: -i))
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
               |> Repo.preload([:contract_creation_transaction])
               |> Address.preload_contract_creation_internal_transaction()
             )

    :timer.sleep(300)

    assert [%{from_number: 1, to_number: 1, priority: 1}] = Repo.all(MissingBlockRange)

    assert :ets.lookup(:contract_creator_lookup, "pending_blocks") == [
             {"pending_blocks", [%{block_number: 1, address_hash_string: contract_address_hash}]}
           ]
  end

  test "retries when eth_getTransactionCount returns an error tuple" do
    contract_address =
      insert(:address, contract_code: "0x1234")

    now = Timex.now()

    Enum.each(0..4, fn i ->
      insert(:block, number: i, refetch_needed: i == 3, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    EthereumJSONRPC.Mox
    |> eth_get_transaction_count_error_mock(contract_address_hash, "0x2")
    |> eth_get_transaction_count_mock(contract_address_hash, "0x2", "0x0")
    |> eth_get_transaction_count_mock(contract_address_hash, "0x3", "0x1")

    pid = Process.whereis(ContractCreatorOnDemand)

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction])
               |> Address.preload_contract_creation_internal_transaction()
             )

    :timer.sleep(1200)

    assert Process.whereis(ContractCreatorOnDemand) == pid
    assert [%{from_number: 3, to_number: 3, priority: 1}] = Repo.all(MissingBlockRange)
  end

  test "stops retrying after 5 JSON RPC errors" do
    contract_address =
      insert(:address, contract_code: "0x1234")

    now = Timex.now()

    Enum.each(0..4, fn i ->
      insert(:block, number: i, refetch_needed: i == 3, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    EthereumJSONRPC.Mox
    |> eth_get_transaction_count_error_mock_times(contract_address_hash, "0x2", 7)

    pid = Process.whereis(ContractCreatorOnDemand)

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction])
               |> Address.preload_contract_creation_internal_transaction()
             )

    :timer.sleep(5400)

    assert Process.whereis(ContractCreatorOnDemand) == pid
    assert [] == Repo.all(MissingBlockRange)
    assert [] == :ets.lookup(:contract_creator_lookup, contract_address_hash)
  end

  # Regression: per-address ETS entry must be updated to the resolved integer block number
  # after a successful fetch. Previously it was left as :in_progress, which caused
  # trigger_fetch/1 to keep returning :ignore and never re-trigger, masking stalls, or to
  # re-dispatch indefinitely when the guard was removed.
  test "stamps the resolved block number in the per-address ETS entry after a successful fetch" do
    contract_address =
      insert(:address, contract_code: "0x1234")

    now = Timex.now()

    Enum.each(0..4, fn i ->
      insert(:block, number: i, refetch_needed: i == 3, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    EthereumJSONRPC.Mox
    |> eth_get_transaction_count_mock(contract_address_hash, "0x2", "0x0")
    |> eth_get_transaction_count_mock(contract_address_hash, "0x3", "0x1")

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction])
               |> Address.preload_contract_creation_internal_transaction()
             )

    :timer.sleep(300)

    # Must be the resolved integer, not the :in_progress atom that was written at fetch start
    assert :ets.lookup(:contract_creator_lookup, contract_address_hash) == [
             {contract_address_hash, 3}
           ]
  end

  # Regression: Enum.member?(pending_blocks, block_number) compared an integer against a
  # list of maps and was always false, allowing the same address to accumulate duplicate
  # entries in pending_blocks. The fix uses Enum.reject/2 on address_hash_string so a
  # stale entry is replaced rather than duplicated.
  test "replaces a stale pending_blocks entry for the same address instead of duplicating it" do
    contract_address =
      insert(:address, contract_code: "0x1234")

    now = Timex.now()

    Enum.each(0..4, fn i ->
      insert(:block, number: i, refetch_needed: i == 3, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    # Pre-seed a stale pending_blocks entry for the same address at a different block (999).
    # Without the fix, Enum.member?(pending_blocks, 3) would be false (integer vs map),
    # the new entry would be prepended, and the list would grow to two entries.
    :ets.insert(
      :contract_creator_lookup,
      {"pending_blocks", [%{block_number: 999, address_hash_string: contract_address_hash}]}
    )

    EthereumJSONRPC.Mox
    |> eth_get_transaction_count_mock(contract_address_hash, "0x2", "0x0")
    |> eth_get_transaction_count_mock(contract_address_hash, "0x3", "0x1")

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction])
               |> Address.preload_contract_creation_internal_transaction()
             )

    :timer.sleep(300)

    # Exactly one entry for this address — the stale block 999 entry was replaced
    assert :ets.lookup(:contract_creator_lookup, "pending_blocks") == [
             {"pending_blocks", [%{block_number: 3, address_hash_string: contract_address_hash}]}
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

  defp eth_get_transaction_count_error_mock(mox, contract_address_hash, block_number) do
    mox
    |> expect(:json_rpc, fn %{
                              id: _id,
                              jsonrpc: "2.0",
                              method: "eth_getTransactionCount",
                              params: [^contract_address_hash, ^block_number]
                            },
                            _ ->
      {:error,
       %{
         code: -32000,
         message: "missing trie node 0000000000000000000000000000000000000000000000000000000000000000 (path )"
       }}
    end)
  end

  defp eth_get_transaction_count_error_mock_times(mox, contract_address_hash, block_number, times) do
    Enum.reduce(1..times, mox, fn _, acc ->
      eth_get_transaction_count_error_mock(acc, contract_address_hash, block_number)
    end)
  end
end
