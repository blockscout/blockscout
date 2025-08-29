defmodule Indexer.Fetcher.SignedAuthorizationStatusTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  import Mox

  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.{Data, SignedAuthorization, SmartContract.Proxy.Models.Implementation}
  alias Explorer.TestHelper
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.SignedAuthorizationStatus

  @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    Supervisor.terminate_child(Explorer.Supervisor, ChainId.child_id())
    Supervisor.restart_child(Explorer.Supervisor, ChainId.child_id())

    :ok
  end

  describe "async_fetch/1" do
    test "fetched authorization statuses, proxy implementations and nonces", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      SignedAuthorizationStatus.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      block1 = insert(:block, number: 1010)
      block2 = insert(:block, number: 1020)

      delegate1 = insert(:address)
      delegate2 = insert(:address)

      address1 = insert(:address)
      address2 = insert(:address)
      address3 = insert(:address)
      address4 = insert(:address)
      address5 = insert(:address)

      transaction11 = insert(:transaction, from_address: address1, nonce: 100, type: 2) |> with_block(block1)
      transaction12 = insert(:transaction, from_address: address1, nonce: 101, type: 2) |> with_block(block1)
      transaction13 = insert(:transaction, from_address: address2, nonce: 200, type: 4) |> with_block(block1)
      transaction14 = insert(:transaction, from_address: address1, nonce: 103, type: 4) |> with_block(block1)
      transaction15 = insert(:transaction, from_address: address5, nonce: 500, type: 4) |> with_block(block1)

      transaction21 = insert(:transaction, from_address: address3, nonce: 300, type: 4) |> with_block(block2)
      transaction22 = insert(:transaction, from_address: address1, nonce: 105, type: 2) |> with_block(block2)
      transaction23 = insert(:transaction, from_address: address5, nonce: 502, type: 4) |> with_block(block2)

      # invalid signature
      auth1 =
        insert(:signed_authorization,
          transaction: transaction13,
          index: 0,
          address: delegate1.hash,
          authority: nil,
          nonce: 102
        )

      # invalid chain id
      auth2 =
        insert(:signed_authorization,
          transaction: transaction13,
          index: 1,
          address: delegate1.hash,
          authority: address1.hash,
          nonce: 102,
          chain_id: 123
        )

      # known nonce, invalid nonce
      auth3 =
        insert(:signed_authorization,
          transaction: transaction13,
          index: 2,
          address: delegate1.hash,
          authority: address1.hash,
          nonce: 77
        )

      # known nonce, all ok
      auth4 =
        insert(:signed_authorization,
          transaction: transaction13,
          index: 3,
          address: delegate1.hash,
          authority: address1.hash,
          nonce: 102
        )

      # known nonce, all ok
      auth5 =
        insert(:signed_authorization,
          transaction: transaction13,
          index: 4,
          address: delegate1.hash,
          authority: address2.hash,
          nonce: 201
        )

      # known nonce, all ok
      auth6 =
        insert(:signed_authorization,
          transaction: transaction13,
          index: 5,
          address: delegate2.hash,
          authority: address2.hash,
          nonce: 202
        )

      # unknown nonce, invalid nonce
      auth7 =
        insert(:signed_authorization,
          transaction: transaction13,
          index: 6,
          address: delegate1.hash,
          authority: address3.hash,
          nonce: 77
        )

      # unknown nonce, all ok
      auth8 =
        insert(:signed_authorization,
          transaction: transaction13,
          index: 7,
          address: delegate1.hash,
          authority: address4.hash,
          nonce: 400
        )

      # unknown nonce, all ok
      auth9 =
        insert(:signed_authorization,
          transaction: transaction14,
          index: 0,
          address: delegate2.hash,
          authority: address4.hash,
          nonce: 401
        )

      # known nonce, all ok
      auth10 =
        insert(:signed_authorization,
          transaction: transaction15,
          index: 0,
          address: delegate1.hash,
          authority: address5.hash,
          nonce: 501
        )

      # unknown nonce, all ok
      auth11 =
        insert(:signed_authorization,
          transaction: transaction21,
          index: 0,
          address: delegate2.hash,
          authority: address1.hash,
          nonce: 104
        )

      # known nonce, all ok
      auth12 =
        insert(:signed_authorization,
          transaction: transaction23,
          index: 0,
          address: "0x0000000000000000000000000000000000000000",
          authority: address5.hash,
          nonce: 503
        )

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        block1_quantity = integer_to_quantity(block1.number - 1)
        block2_quantity = integer_to_quantity(block2.number - 1)
        address1_string = to_string(address1.hash)
        address3_string = to_string(address3.hash)
        address4_string = to_string(address4.hash)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: id2,
                                    method: "eth_getTransactionCount",
                                    params: [^address4_string, ^block1_quantity]
                                  },
                                  %{
                                    id: id1,
                                    method: "eth_getTransactionCount",
                                    params: [^address3_string, ^block1_quantity]
                                  },
                                  %{
                                    id: id3,
                                    method: "eth_getTransactionCount",
                                    params: [^address1_string, ^block2_quantity]
                                  }
                                ],
                                _options ->
          {:ok,
           [
             %{id: id1, result: integer_to_quantity(300)},
             %{id: id2, result: integer_to_quantity(400)},
             %{id: id3, result: integer_to_quantity(104)}
           ]}
        end)

        TestHelper.get_chain_id_mock()
      end

      addresses = [address1, address2, address3, address4, address5]

      transactions = [
        transaction11,
        transaction12,
        transaction13,
        transaction14,
        transaction15,
        transaction21,
        transaction22,
        transaction23
      ]

      auths = [auth1, auth2, auth3, auth4, auth5, auth6, auth7, auth8, auth9, auth10, auth11, auth12]

      assert :ok = SignedAuthorizationStatus.async_fetch(transactions, auths, false)

      wait_for_tasks(SignedAuthorizationStatus)

      auths = from(auth in SignedAuthorization, order_by: [asc: :transaction_hash, asc: :index]) |> Repo.all()

      assert auths |> Enum.map(& &1.status) == [
               :invalid_signature,
               :invalid_chain_id,
               :invalid_nonce,
               :ok,
               :ok,
               :ok,
               :invalid_nonce,
               :ok,
               :ok,
               :ok,
               :ok,
               :ok
             ]

      addresses =
        addresses
        |> Repo.reload()
        |> Repo.preload(Implementation.proxy_implementations_association())

      assert addresses |> Enum.map(& &1.nonce) == [
               104,
               202,
               nil,
               401,
               503
             ]

      assert addresses |> Enum.map(& &1.contract_code) == [
               %Data{bytes: <<239, 1, 0>> <> delegate2.hash.bytes},
               %Data{bytes: <<239, 1, 0>> <> delegate2.hash.bytes},
               nil,
               %Data{bytes: <<239, 1, 0>> <> delegate2.hash.bytes},
               nil
             ]

      assert addresses |> Enum.map(&((&1.proxy_implementations || %{}) |> Map.get(:address_hashes))) == [
               [delegate2.hash],
               [delegate2.hash],
               nil,
               [delegate2.hash],
               nil
             ]
    end
  end

  defp wait_for_tasks(buffered_task) do
    wait_until(:timer.seconds(10), fn ->
      counts = BufferedTask.debug_count(buffered_task)
      counts.buffer == 0 and counts.tasks == 0
    end)
  end

  defp wait_until(timeout, producer) do
    parent = self()
    ref = make_ref()

    spawn(fn -> do_wait_until(parent, ref, producer) end)

    receive do
      {^ref, :ok} -> :ok
    after
      timeout -> exit(:timeout)
    end
  end

  defp do_wait_until(parent, ref, producer) do
    if producer.() do
      send(parent, {ref, :ok})
    else
      :timer.sleep(100)
      do_wait_until(parent, ref, producer)
    end
  end
end
