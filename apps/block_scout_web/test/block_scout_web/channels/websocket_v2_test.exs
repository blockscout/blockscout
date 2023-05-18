defmodule BlockScoutWeb.WebsocketV2Test do
  use BlockScoutWeb.ChannelCase, async: false

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.{Address, Import, InternalTransaction, Log, Token, TokenTransfer, Transaction}
  alias Explorer.Repo

  describe "websocket v2" do
    @import_data %{
      blocks: %{
        params: [
          %{
            consensus: true,
            difficulty: 340_282_366_920_938_463_463_374_607_431_768_211_454,
            gas_limit: 6_946_336,
            gas_used: 50450,
            hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            nonce: 0,
            number: 37,
            parent_hash: "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
            size: 719,
            timestamp: Timex.parse!("2017-12-15T21:06:30.000000Z", "{ISO:Extended:Z}"),
            total_difficulty: 12_590_447_576_074_723_148_144_860_474_975_121_280_509
          }
        ],
        timeout: 5
      },
      broadcast: :realtime,
      logs: %{
        params: [
          %{
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            data: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            second_topic: "0x000000000000000000000000e8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            third_topic: "0x000000000000000000000000515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            fourth_topic: nil,
            index: 0,
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "mined"
          },
          %{
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            data: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            second_topic: "0x000000000000000000000000e8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            third_topic: "0x000000000000000000000000515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            fourth_topic: nil,
            index: 1,
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "mined"
          },
          %{
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            data: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            second_topic: "0x000000000000000000000000e8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            third_topic: "0x000000000000000000000000515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            fourth_topic: nil,
            index: 2,
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "mined"
          }
        ],
        timeout: 5
      },
      transactions: %{
        params: [
          %{
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            block_number: 37,
            cumulative_gas_used: 50450,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_700_000,
            gas_price: 100_000_000_000,
            gas_used: 50450,
            hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            index: 0,
            input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
            nonce: 4,
            public_key:
              "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
            r: 0xA7F8F45CCE375BB7AF8750416E1B03E0473F93C256DA2285D1134FC97A700E01,
            s: 0x1F87A076F13824F4BE8963E3DFFD7300DAE64D5F23C9A062AF0C6EAD347C135F,
            standard_v: 1,
            status: :ok,
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            v: 0xBE,
            value: 0
          },
          %{
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            block_number: 37,
            cumulative_gas_used: 50450,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_700_000,
            gas_price: 100_000_000_000,
            gas_used: 50450,
            hash: "0x00bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e1",
            index: 1,
            input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
            nonce: 5,
            public_key:
              "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
            r: 0xA7F8F45CCE375BB7AF8750416E1B03E0473F93C256DA2285D1134FC97A700E09,
            s: 0x1F87A076F13824F4BE8963E3DFFD7300DAE64D5F23C9A062AF0C6EAD347C1354,
            standard_v: 1,
            status: :ok,
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            v: 0xBE,
            value: 0
          },
          %{
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_700_000,
            gas_price: 100_000_000_000,
            hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e0",
            input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
            nonce: 6,
            public_key:
              "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
            r: 0xA7F8F45CCE375BB7AF8750416E1B03E0473F93C256DA2285D1134FC97A700E09,
            s: 0x1F87A076F13824F4BE8963E3DFFD7300DAE64D5F23C9A062AF0C6EAD347C1354,
            standard_v: 1,
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            v: 0xBE,
            value: 0
          },
          %{
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_700_000,
            gas_price: 100_000_000_000,
            hash: "0x00bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd43312",
            input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
            nonce: 7,
            public_key:
              "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
            r: 0xA7F8F45CCE375BB7AF8750416E1B03E0473F93C256DA2285D1134FC97A700E09,
            s: 0x1F87A076F13824F4BE8963E3DFFD7300DAE64D5F23C9A062AF0C6EAD347C1354,
            standard_v: 1,
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            v: 0xBE,
            value: 0
          }
        ],
        timeout: 5
      },
      addresses: %{
        params: [
          %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"},
          %{hash: "0x00f38d4764929064f2d4d3a56520a76ab3df4151"},
          %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"},
          %{hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d"}
        ],
        timeout: 5
      },
      tokens: %{
        on_conflict: :nothing,
        params: [
          %{
            contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            type: "ERC-20"
          },
          %{
            contract_address_hash: "0x00f38d4764929064f2d4d3a56520a76ab3df4151",
            type: "ERC-20"
          }
        ],
        timeout: 5
      },
      token_transfers: %{
        params: [
          %{
            amount: Decimal.new(1_000_000_000_000_000_000),
            block_number: 37,
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            log_index: 0,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            to_address_hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            token_contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
          },
          %{
            amount: Decimal.new(1_000_000_000_000_000_000),
            block_number: 37,
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            log_index: 1,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            to_address_hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            token_contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
          },
          %{
            amount: Decimal.new(1_000_000_000_000_000_000),
            block_number: 37,
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            log_index: 2,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            to_address_hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            token_contract_address_hash: "0x00f38d4764929064f2d4d3a56520a76ab3df4151",
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
          }
        ],
        timeout: 5
      }
    }

    test "broadcasted several transactions in one message" do
      topic = "transactions:new_transaction"

      {:ok, _reply, _socket} =
        BlockScoutWeb.UserSocketV2
        |> socket("no_id", %{})
        |> subscribe_and_join(topic)

      topic_pending = "transactions:new_pending_transaction"

      {:ok, _reply, _socket} =
        BlockScoutWeb.UserSocketV2
        |> socket("no_id", %{})
        |> subscribe_and_join(topic_pending)

      Subscriber.to(:transactions, :realtime)
      Import.all(@import_data)
      assert_receive {:chain_event, :transactions, :realtime, txs}, :timer.seconds(5)

      Notifier.handle_event({:chain_event, :transactions, :realtime, txs})

      assert_receive %Phoenix.Socket.Message{
                       payload: %{transaction: 2},
                       event: "transaction",
                       topic: ^topic
                     },
                     :timer.seconds(5)

      assert_receive %Phoenix.Socket.Message{
                       payload: %{pending_transaction: 2},
                       event: "pending_transaction",
                       topic: ^topic_pending
                     },
                     :timer.seconds(5)
    end

    test "broadcast token transfers" do
      topic_token = "tokens:0x8bf38d4764929064f2d4d3a56520a76ab3df415b"

      {:ok, _reply, _socket} =
        BlockScoutWeb.UserSocketV2
        |> socket("no_id", %{})
        |> subscribe_and_join(topic_token)

      Subscriber.to(:token_transfers, :realtime)

      Import.all(@import_data)

      assert_receive {:chain_event, :token_transfers, :realtime, token_transfers}, :timer.seconds(5)

      Notifier.handle_event({:chain_event, :token_transfers, :realtime, token_transfers})

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_transfer: 2},
                       event: "token_transfer",
                       topic: ^topic_token
                     },
                     :timer.seconds(5)
    end

    test "broadcast array of txs to address" do
      topic = "addresses:0x8bf38d4764929064f2d4d3a56520a76ab3df415b"

      {:ok, _reply, _socket} =
        BlockScoutWeb.UserSocketV2
        |> socket("no_id", %{})
        |> subscribe_and_join(topic)

      Subscriber.to(:transactions, :realtime)
      Import.all(@import_data)

      assert_receive {:chain_event, :transactions, :realtime, txs}, :timer.seconds(5)
      Notifier.handle_event({:chain_event, :transactions, :realtime, txs})

      assert_receive %Phoenix.Socket.Message{
                       payload: %{transactions: [tx_1, tx_2]},
                       event: "transaction",
                       topic: ^topic
                     },
                     :timer.seconds(5)

      tx_1 = tx_1 |> Jason.encode!() |> Jason.decode!()
      compare_item(Repo.get_by(Transaction, %{hash: tx_1["hash"]}), tx_1)

      tx_2 = tx_2 |> Jason.encode!() |> Jason.decode!()
      compare_item(Repo.get_by(Transaction, %{hash: tx_2["hash"]}), tx_2)

      assert_receive %Phoenix.Socket.Message{
                       payload: %{transactions: [tx_1, tx_2]},
                       event: "pending_transaction",
                       topic: ^topic
                     },
                     :timer.seconds(5)

      tx_1 = tx_1 |> Jason.encode!() |> Jason.decode!()
      compare_item(Repo.get_by(Transaction, %{hash: tx_1["hash"]}), tx_1)

      tx_2 = tx_2 |> Jason.encode!() |> Jason.decode!()
      compare_item(Repo.get_by(Transaction, %{hash: tx_2["hash"]}), tx_2)
    end

    test "broadcast array of transfers to address" do
      topic = "addresses:0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"

      {:ok, _reply, _socket} =
        BlockScoutWeb.UserSocketV2
        |> socket("no_id", %{})
        |> subscribe_and_join(topic)

      topic_1 = "addresses:0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d"

      {:ok, _reply, _socket} =
        BlockScoutWeb.UserSocketV2
        |> socket("no_id", %{})
        |> subscribe_and_join(topic_1)

      Subscriber.to(:token_transfers, :realtime)
      Import.all(@import_data)

      assert_receive {:chain_event, :token_transfers, :realtime, token_transfers}, :timer.seconds(5)
      Notifier.handle_event({:chain_event, :token_transfers, :realtime, token_transfers})

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_transfers: [_, _, _] = transfers},
                       event: "token_transfer",
                       topic: ^topic
                     },
                     :timer.seconds(5)

      token_transfers
      |> Enum.zip(transfers)
      |> Enum.each(fn {transfer, json} -> compare_item(transfer, json |> Jason.encode!() |> Jason.decode!()) end)

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_transfers: [_, _, _] = transfers},
                       event: "token_transfer",
                       topic: ^topic_1
                     },
                     :timer.seconds(5)

      token_transfers
      |> Enum.zip(transfers)
      |> Enum.each(fn {transfer, json} -> compare_item(transfer, json |> Jason.encode!() |> Jason.decode!()) end)
    end
  end

  defp compare_item(%TokenTransfer{} = token_transfer, json) do
    assert Address.checksum(token_transfer.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(token_transfer.to_address_hash) == json["to"]["hash"]
    assert to_string(token_transfer.transaction_hash) == json["tx_hash"]
    assert json["timestamp"] != nil
    assert json["method"] != nil
    assert to_string(token_transfer.block_hash) == json["block_hash"]
    assert to_string(token_transfer.log_index) == json["log_index"]
    assert check_total(Repo.preload(token_transfer, [{:token, :contract_address}]).token, json["total"], token_transfer)
  end

  defp compare_item(%Transaction{} = transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]
  end

  defp check_total(%Token{type: nft}, json, token_transfer) when nft in ["ERC-1155"] do
    json["token_id"] in Enum.map(token_transfer.token_ids, fn x -> to_string(x) end) and
      json["value"] == to_string(token_transfer.amount)
  end

  defp check_total(%Token{type: nft}, json, token_transfer) when nft in ["ERC-721"] do
    json["token_id"] in Enum.map(token_transfer.token_ids, fn x -> to_string(x) end)
  end

  # with the current implementation no transfers should come with list in totals
  defp check_total(%Token{type: nft}, json, _token_transfer) when nft in ["ERC-721", "ERC-1155"] and is_list(json) do
    false
  end

  defp check_total(_, _, _), do: true
end
