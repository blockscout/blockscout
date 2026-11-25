# SPDX-License-Identifier: LicenseRef-Blockscout
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

  describe "async_fetch/3 with EIP-8430 transactions" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      SignedAuthorizationStatus.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      :ok
    end

    test "requests the nonce from the node if the signer sent a transaction of a nonce channel earlier in the block",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{block: block, signer: signer, transactions: transactions, authorization: authorization} =
        insert_block_with_authorization(
          signer_transactions: [%{nonce: 7, type: 0x79, nonce_key: 5}],
          authorization_nonce: 100
        )

      expect_nonce_request(json_rpc_named_arguments, signer, block, {:ok, 100})
      expect_chain_id_request(json_rpc_named_arguments)

      assert :ok = SignedAuthorizationStatus.async_fetch(transactions, [authorization], false)

      assert wait_for_status(authorization) == :ok
    end

    test "requests the nonce from the node if the signer sent a nonce-free transaction earlier in the block",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{block: block, signer: signer, transactions: transactions, authorization: authorization} =
        insert_block_with_authorization(
          signer_transactions: [%{nonce: 0, type: 0x79, nonce_key: Bitwise.bsl(1, 256) - 1}],
          authorization_nonce: 100
        )

      expect_nonce_request(json_rpc_named_arguments, signer, block, {:ok, 100})
      expect_chain_id_request(json_rpc_named_arguments)

      assert :ok = SignedAuthorizationStatus.async_fetch(transactions, [authorization], false)

      assert wait_for_status(authorization) == :ok
    end

    test "uses the nonce of an EIP-8430 transaction with `nonce_key` 0 and sends no request to the node",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{transactions: transactions, authorization: authorization} =
        insert_block_with_authorization(
          signer_transactions: [%{nonce: 7, type: 0x79, nonce_key: 0}],
          authorization_nonce: 8
        )

      # No expectation for `eth_getTransactionCount`: such a request makes the fetcher fail.
      expect_chain_id_request(json_rpc_named_arguments)

      assert :ok = SignedAuthorizationStatus.async_fetch(transactions, [authorization], false)

      assert wait_for_status(authorization) == :ok
    end

    test "calculates the account nonce from the usual transaction, not from the transaction of a nonce channel",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{transactions: transactions, authorization: authorization} =
        insert_block_with_authorization(
          signer_transactions: [%{nonce: 50, type: 2}, %{nonce: 900, type: 0x79, nonce_key: 5}],
          authorization_nonce: 51
        )

      # No expectation for `eth_getTransactionCount`: such a request makes the fetcher fail.
      expect_chain_id_request(json_rpc_named_arguments)

      assert :ok = SignedAuthorizationStatus.async_fetch(transactions, [authorization], false)

      assert wait_for_status(authorization) == :ok
    end

    test "requests the nonce from the node for an EIP-8430 transaction without a row in `eip_8430_transactions`",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{block: block, signer: signer, transactions: transactions, authorization: authorization} =
        insert_block_with_authorization(
          signer_transactions: [%{nonce: 7, type: 0x79}],
          authorization_nonce: 100
        )

      expect_nonce_request(json_rpc_named_arguments, signer, block, {:ok, 100})
      expect_chain_id_request(json_rpc_named_arguments)

      assert :ok = SignedAuthorizationStatus.async_fetch(transactions, [authorization], false)

      assert wait_for_status(authorization) == :ok
    end

    test "a retry after a failed nonce request does not use the transaction of a nonce channel",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{block: block, signer: signer, transactions: transactions, authorization: authorization} =
        insert_block_with_authorization(
          signer_transactions: [%{nonce: 7, type: 0x79, nonce_key: 5}],
          authorization_nonce: 100
        )

      # The first `run/2` fails and returns its entries for a retry. These entries have the old
      # form, without the hash and the type of the transaction. If the second `run/2` used the
      # nonce of the EIP-8430 transaction, it would send no request and the status would be
      # `invalid_nonce`.
      expect_nonce_request(json_rpc_named_arguments, signer, block, {:error, :timeout})
      expect_nonce_request(json_rpc_named_arguments, signer, block, {:ok, 100})
      expect_chain_id_request(json_rpc_named_arguments)

      assert :ok = SignedAuthorizationStatus.async_fetch(transactions, [authorization], false)

      assert wait_for_status(authorization) == :ok
    end
  end

  describe "async_fetch/3 when the node returns no nonce for the signer" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      SignedAuthorizationStatus.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      :ok
    end

    test "retries the block until the node returns the nonce",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{block: block, signer: signer, transactions: transactions, authorization: authorization} =
        insert_block_with_authorization(signer_transactions: [], authorization_nonce: 100)

      # The first request is successful as a whole, but the node returns an error for the address of
      # the signer. The first `run/2` cannot calculate the status, so the status stays `nil`. The
      # fetcher must return the block for a retry. Without the retry, the second request does not
      # occur and the status stays `nil`.
      #
      # The first `run/2` reads the chain ID after the nonce request, so the chain ID request is
      # the second request.
      expect_nonce_request(json_rpc_named_arguments, signer, block, {:address_error, "header not found"})
      expect_chain_id_request(json_rpc_named_arguments)
      expect_nonce_request(json_rpc_named_arguments, signer, block, {:ok, 100})

      assert :ok = SignedAuthorizationStatus.async_fetch(transactions, [authorization], false)

      assert wait_for_status(authorization) == :ok
    end
  end

  describe "init/3 with EIP-8430 transactions" do
    test "requests the nonce from the node for a block that the fetcher loads from the database",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{block: block, signer: signer, authorization: authorization} =
        insert_block_with_authorization(
          signer_transactions: [%{nonce: 7, type: 0x79, nonce_key: 5}],
          authorization_nonce: 100
        )

      expect_nonce_request(json_rpc_named_arguments, signer, block, {:ok, 100})
      expect_chain_id_request(json_rpc_named_arguments)

      # The entry from `init/3` has no transactions. `preload_entries/1` loads them in `run/2`.
      SignedAuthorizationStatus.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      assert wait_for_status(authorization) == :ok
    end
  end

  # Inserts one block. First the signer sends `signer_transactions` in the given order. Then a
  # different sender sends an EIP-7702 transaction with one authorization of the signer.
  #
  # Each item of `signer_transactions` has `:nonce`, `:type`, and an optional `:nonce_key`. An item
  # with `:nonce_key` gets a row in `eip_8430_transactions`.
  defp insert_block_with_authorization(options) do
    # The fetcher requests the nonce at the block before `block`. The first block of the factory
    # can have the number 0, which has no block before it. This block takes that number.
    insert(:block)
    block = insert(:block)
    signer = insert(:address)

    signer_transactions =
      options
      |> Keyword.fetch!(:signer_transactions)
      |> Enum.map(fn %{nonce: nonce, type: type} = params ->
        transaction = :transaction |> insert(from_address: signer, nonce: nonce, type: type) |> with_block(block)

        if Map.has_key?(params, :nonce_key) do
          insert(:eip_8430_transaction, transaction: transaction, nonce_key: params.nonce_key)
        end

        transaction
      end)

    authorization_transaction = :transaction |> insert(nonce: 1, type: 4) |> with_block(block)

    authorization =
      insert(:signed_authorization,
        transaction: authorization_transaction,
        index: 0,
        address: insert(:address).hash,
        authority: signer.hash,
        nonce: Keyword.fetch!(options, :authorization_nonce)
      )

    %{
      block: block,
      signer: signer,
      transactions: signer_transactions ++ [authorization_transaction],
      authorization: authorization
    }
  end

  # Expects one `eth_getTransactionCount` request for the nonce of `address` at the end of the
  # block before `block`. `result` is `{:ok, nonce}`, `{:address_error, message}` for an error that
  # the node returns only for this address, or an error of the transport.
  defp expect_nonce_request(json_rpc_named_arguments, address, block, result) do
    if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
      address_string = to_string(address.hash)
      block_quantity = integer_to_quantity(block.number - 1)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                  %{
                                                    id: id,
                                                    method: "eth_getTransactionCount",
                                                    params: [^address_string, ^block_quantity]
                                                  }
                                                ],
                                                _options ->
        case result do
          {:ok, nonce} -> {:ok, [%{id: id, result: integer_to_quantity(nonce)}]}
          {:address_error, message} -> {:ok, [%{id: id, error: %{code: -32000, message: message}}]}
          error -> error
        end
      end)
    end

    :ok
  end

  defp expect_chain_id_request(json_rpc_named_arguments) do
    if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
      TestHelper.get_chain_id_mock()
    end

    :ok
  end

  # Waits until the fetcher writes a status to the authorization, and returns the status.
  defp wait_for_status(authorization) do
    wait_until(:timer.seconds(10), fn ->
      not is_nil(reload_status(authorization))
    end)

    wait_for_tasks(SignedAuthorizationStatus)

    reload_status(authorization)
  end

  defp reload_status(authorization) do
    Repo.one!(
      from(signed_authorization in SignedAuthorization,
        where:
          signed_authorization.transaction_hash == ^authorization.transaction_hash and
            signed_authorization.index == ^authorization.index,
        select: signed_authorization.status
      )
    )
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
