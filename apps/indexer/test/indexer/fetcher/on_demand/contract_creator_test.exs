# SPDX-License-Identifier: LicenseRef-Blockscout
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
                 |> Address.maybe_preload_contract_creation_internal_transaction([])
               )
    end

    test "does nothing if creation transaction block number lookup is in progress" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      :ets.insert(
        :contract_creator_lookup,
        {to_string(contract_address.hash), {:in_progress, make_ref()}, monotonic_now()}
      )

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction])
                 |> Address.maybe_preload_contract_creation_internal_transaction([])
               )
    end

    test "does nothing if creation transaction block number lookup is in progress while other blocks are pending" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      other_contract_address = insert(:address, contract_code: "0x5678")

      :ets.insert(
        :contract_creator_lookup,
        {to_string(contract_address.hash), {:in_progress, make_ref()}, monotonic_now()}
      )

      :ets.insert(:contract_creator_lookup, {to_string(other_contract_address.hash), 12345, monotonic_now()})
      :ets.insert(:contract_creator_lookup, {{:pending_block, 12345}, [to_string(other_contract_address.hash)]})

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction])
                 |> Address.maybe_preload_contract_creation_internal_transaction([])
               )
    end

    test "does nothing if creation transaction block number lookup, but indexing of corresponding block is not yet started" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      :ets.insert(:contract_creator_lookup, {to_string(contract_address.hash), 12345, monotonic_now()})

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction])
                 |> Address.maybe_preload_contract_creation_internal_transaction([])
               )
    end

    test "does nothing if creation transaction block number lookup, but indexing of corresponding block is in progress" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      :ets.insert(:contract_creator_lookup, {to_string(contract_address.hash), 12345, monotonic_now()})
      :ets.insert(:contract_creator_lookup, {{:pending_block, 12345}, [to_string(contract_address.hash)]})

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction])
                 |> Address.maybe_preload_contract_creation_internal_transaction([])
               )
    end

    test "does not crash when ETS table is unavailable" do
      contract_address =
        insert(:address, contract_code: "0x1234")

      :ets.delete(:contract_creator_lookup)

      assert :ignore =
               ContractCreatorOnDemand.trigger_fetch(
                 contract_address
                 |> Repo.preload([:contract_creation_transaction])
                 |> Address.maybe_preload_contract_creation_internal_transaction([])
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
                 |> Address.maybe_preload_contract_creation_internal_transaction([])
               )

      :timer.sleep(300)

      assert [%{from_number: 3, to_number: 3, priority: 1}] = Repo.all(MissingBlockRange)

      assert :ets.lookup(:contract_creator_lookup, {:pending_block, 3}) == [
               {{:pending_block, 3}, [contract_address_hash]}
             ]
    end

    test "returns :ignore when ETS table does not exist (GenServer not started)" do
      :ets.delete(:contract_creator_lookup)

      address = insert(:address, contract_code: "0x1234")

      assert :ignore = ContractCreatorOnDemand.trigger_fetch(address)
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
               |> Address.maybe_preload_contract_creation_internal_transaction([])
             )

    :timer.sleep(300)

    assert [%{from_number: 2, to_number: 2, priority: 1}] = Repo.all(MissingBlockRange)

    assert :ets.lookup(:contract_creator_lookup, {:pending_block, 2}) == [
             {{:pending_block, 2}, [contract_address_hash]}
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
               |> Address.maybe_preload_contract_creation_internal_transaction([])
             )

    :timer.sleep(300)

    assert [%{from_number: 1, to_number: 1, priority: 1}] = Repo.all(MissingBlockRange)

    assert :ets.lookup(:contract_creator_lookup, {:pending_block, 1}) == [
             {{:pending_block, 1}, [contract_address_hash]}
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
               |> Address.maybe_preload_contract_creation_internal_transaction([])
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
    |> eth_get_transaction_count_error_mock_times(contract_address_hash, "0x2", 6)

    pid = Process.whereis(ContractCreatorOnDemand)

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction])
               |> Address.maybe_preload_contract_creation_internal_transaction([])
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
               |> Address.maybe_preload_contract_creation_internal_transaction([])
             )

    :timer.sleep(300)

    # Must be the resolved integer, not the {:in_progress, _} state that was written at fetch start
    assert [{^contract_address_hash, 3, _updated_at}] = :ets.lookup(:contract_creator_lookup, contract_address_hash)
  end

  # An entry that outlived the TTL is looked up again, and the address moves from the index
  # of its stale block to the block found by the new lookup instead of being listed twice.
  test "looks up an expired entry again and replaces its stale pending block" do
    contract_address =
      insert(:address, contract_code: "0x1234")

    now = Timex.now()

    Enum.each(0..4, fn i ->
      insert(:block, number: i, refetch_needed: i == 3, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    :ets.insert(:contract_creator_lookup, {contract_address_hash, 999, monotonic_now() - :timer.hours(24)})
    :ets.insert(:contract_creator_lookup, {{:pending_block, 999}, [contract_address_hash]})

    stub_eth_get_transaction_count(contract_address_hash, fn block_number ->
      if block_number == "0x2", do: "0x0", else: "0x1"
    end)

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction])
               |> Address.maybe_preload_contract_creation_internal_transaction([])
             )

    assert_receive {:eth_get_transaction_count, lookup_pid, "0x2"}, 1_000
    await_lookup(lookup_pid)

    assert [] == :ets.lookup(:contract_creator_lookup, {:pending_block, 999})

    assert :ets.lookup(:contract_creator_lookup, {:pending_block, 3}) == [
             {{:pending_block, 3}, [contract_address_hash]}
           ]

    assert [{^contract_address_hash, 3, _updated_at}] = :ets.lookup(:contract_creator_lookup, contract_address_hash)
  end

  test "starts a single lookup when fetches for the same address arrive before the first one is handled" do
    contract_address =
      insert(:address, contract_code: "0x1234")

    now = Timex.now()

    Enum.each(0..4, fn i ->
      insert(:block, number: i, refetch_needed: i == 3, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    stub_eth_get_transaction_count(contract_address_hash, fn block_number ->
      if block_number == "0x2", do: "0x0", else: "0x1"
    end)

    GenServer.cast(ContractCreatorOnDemand, {:fetch, contract_address})
    GenServer.cast(ContractCreatorOnDemand, {:fetch, contract_address})

    assert_receive {:eth_get_transaction_count, lookup_pid, "0x2"}, 1_000
    await_lookup(lookup_pid)

    assert_received {:eth_get_transaction_count, ^lookup_pid, "0x3"}
    assert [{^contract_address_hash, 3, _updated_at}] = :ets.lookup(:contract_creator_lookup, contract_address_hash)

    # both fetches are handled by now, a second lookup would repeat the calls from another process
    refute_receive {:eth_get_transaction_count, _, _}, 500
  end

  test "clears the in-progress mark when the lookup crashes" do
    contract_address =
      insert(:address, contract_code: "0x1234")

    now = Timex.now()

    Enum.each(0..4, fn i ->
      insert(:block, number: i, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    stub_eth_get_transaction_count(contract_address_hash, fn _block_number -> raise "unexpected response" end)

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction])
               |> Address.maybe_preload_contract_creation_internal_transaction([])
             )

    assert_receive {:eth_get_transaction_count, lookup_pid, "0x2"}, 1_000
    await_lookup(lookup_pid)

    assert [] == :ets.lookup(:contract_creator_lookup, contract_address_hash)
  end

  test "removes the addresses of imported blocks from the cache" do
    imported_hash = to_string(build(:address).hash)
    pending_hash = to_string(build(:address).hash)

    :ets.insert(:contract_creator_lookup, {imported_hash, 3, monotonic_now()})
    :ets.insert(:contract_creator_lookup, {{:pending_block, 3}, [imported_hash]})
    :ets.insert(:contract_creator_lookup, {pending_hash, 5, monotonic_now()})
    :ets.insert(:contract_creator_lookup, {{:pending_block, 5}, [pending_hash]})

    ContractCreatorOnDemand.async_update_cache_of_contract_creator_on_demand(%{blocks: [%{number: 3}]})
    :sys.get_state(ContractCreatorOnDemand)

    assert [] == :ets.lookup(:contract_creator_lookup, imported_hash)
    assert [] == :ets.lookup(:contract_creator_lookup, {:pending_block, 3})
    assert [{^pending_hash, 5, _updated_at}] = :ets.lookup(:contract_creator_lookup, pending_hash)
    assert [{{:pending_block, 5}, [^pending_hash]}] = :ets.lookup(:contract_creator_lookup, {:pending_block, 5})
  end

  test "sweeps expired entries together with their pending blocks" do
    expired_hash = to_string(build(:address).hash)
    expired_in_progress_hash = to_string(build(:address).hash)
    fresh_hash = to_string(build(:address).hash)
    expired_at = monotonic_now() - :timer.hours(24)

    :ets.insert(:contract_creator_lookup, {expired_hash, 7, expired_at})
    :ets.insert(:contract_creator_lookup, {{:pending_block, 7}, [expired_hash]})
    :ets.insert(:contract_creator_lookup, {expired_in_progress_hash, {:in_progress, make_ref()}, expired_at})
    :ets.insert(:contract_creator_lookup, {fresh_hash, 8, monotonic_now()})
    :ets.insert(:contract_creator_lookup, {{:pending_block, 8}, [fresh_hash]})

    send(Process.whereis(ContractCreatorOnDemand), :sweep)
    :sys.get_state(ContractCreatorOnDemand)

    assert [] == :ets.lookup(:contract_creator_lookup, expired_hash)
    assert [] == :ets.lookup(:contract_creator_lookup, {:pending_block, 7})
    assert [] == :ets.lookup(:contract_creator_lookup, expired_in_progress_hash)
    assert [{^fresh_hash, 8, _updated_at}] = :ets.lookup(:contract_creator_lookup, fresh_hash)
    assert [{{:pending_block, 8}, [^fresh_hash]}] = :ets.lookup(:contract_creator_lookup, {:pending_block, 8})
  end

  test "drops the result of a lookup whose entry was taken over by a newer lookup" do
    address_hash = build(:address).hash
    address_hash_string = to_string(address_hash)
    newer_lookup_ref = make_ref()

    :ets.insert(:contract_creator_lookup, {address_hash_string, {:in_progress, newer_lookup_ref}, monotonic_now()})

    GenServer.cast(ContractCreatorOnDemand, {:fetch_result, address_hash, make_ref(), 3})
    GenServer.cast(ContractCreatorOnDemand, {:fetch_result, address_hash, make_ref(), :error})
    :sys.get_state(ContractCreatorOnDemand)

    assert [{^address_hash_string, {:in_progress, ^newer_lookup_ref}, _updated_at}] =
             :ets.lookup(:contract_creator_lookup, address_hash_string)

    assert [] == :ets.lookup(:contract_creator_lookup, {:pending_block, 3})
    assert [] == Repo.all(MissingBlockRange)
  end

  test "drops the result of a lookup whose entry has been swept" do
    address_hash = build(:address).hash
    address_hash_string = to_string(address_hash)

    GenServer.cast(ContractCreatorOnDemand, {:fetch_result, address_hash, make_ref(), 3})
    :sys.get_state(ContractCreatorOnDemand)

    assert [] == :ets.lookup(:contract_creator_lookup, address_hash_string)
    assert [] == :ets.lookup(:contract_creator_lookup, {:pending_block, 3})
    assert [] == Repo.all(MissingBlockRange)
  end

  # Regression: when the address already had a nonce at block 0 (e.g. a genesis contract), the search
  # moved the right border below block 0 and kept querying block 0 forever.
  test "stops the lookup when the address already has a nonce at block 0" do
    contract_address =
      insert(:address, contract_code: "0x1234")

    now = Timex.now()

    Enum.each(0..4, fn i ->
      insert(:block, number: i, timestamp: Timex.shift(now, minutes: -i))
    end)

    Explorer.Chain.Cache.BlockNumber.get_max()

    contract_address_hash = to_string(contract_address.hash)

    stub_eth_get_transaction_count(contract_address_hash, fn _block_number -> "0x1" end)

    assert :ok =
             ContractCreatorOnDemand.trigger_fetch(
               contract_address
               |> Repo.preload([:contract_creation_transaction])
               |> Address.maybe_preload_contract_creation_internal_transaction([])
             )

    assert_receive {:eth_get_transaction_count, lookup_pid, "0x2"}, 1_000
    # without the fix the lookup never ends
    await_lookup(lookup_pid)

    assert_received {:eth_get_transaction_count, ^lookup_pid, "0x1"}
    assert_received {:eth_get_transaction_count, ^lookup_pid, "0x0"}
    refute_received {:eth_get_transaction_count, _, _}

    assert [{^contract_address_hash, :not_found, _updated_at}] =
             :ets.lookup(:contract_creator_lookup, contract_address_hash)

    assert [] == Repo.all(MissingBlockRange)
  end

  defp monotonic_now, do: System.monotonic_time(:millisecond)

  # Answers eth_getTransactionCount for the address with the nonce returned by `nonce_by_block`
  # and reports every call to the test process along with the pid of the lookup that made it
  defp stub_eth_get_transaction_count(contract_address_hash, nonce_by_block) do
    test_pid = self()

    stub(EthereumJSONRPC.Mox, :json_rpc, fn %{
                                              method: "eth_getTransactionCount",
                                              params: [^contract_address_hash, block_number]
                                            },
                                            _ ->
      send(test_pid, {:eth_get_transaction_count, self(), block_number})
      {:ok, nonce_by_block.(block_number)}
    end)
  end

  # The lookup casts its result right before it exits, so once it is down the result is queued
  # in the GenServer ahead of the :sys.get_state/1 request and has been applied when the call returns
  defp await_lookup(lookup_pid) do
    monitor_ref = Process.monitor(lookup_pid)
    assert_receive {:DOWN, ^monitor_ref, :process, ^lookup_pid, _reason}, 1_000
    :sys.get_state(ContractCreatorOnDemand)
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
