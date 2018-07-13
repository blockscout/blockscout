defmodule ExplorerWeb.ViewingTransactionsTest do
  @moduledoc false

  use ExplorerWeb.FeatureCase, async: true

  alias Explorer.Chain
  alias Explorer.Chain.Wei
  alias ExplorerWeb.{AddressPage, HomePage, TransactionListPage, TransactionLogsPage, TransactionPage}

  setup do
    block =
      insert(:block, %{
        number: 555,
        timestamp: Timex.now() |> Timex.shift(hours: -2),
        gas_used: 123_987
      })

    4
    |> insert_list(:transaction)
    |> with_block()

    pending = insert(:transaction, block_hash: nil, gas: 5891, index: nil)
    pending_contract = insert(:transaction, to_address: nil, block_hash: nil, gas: 5891, index: nil)

    lincoln = insert(:address)
    taft = insert(:address)

    transaction =
      :transaction
      |> insert(
        value: Wei.from(Decimal.new(5656), :ether),
        gas: Decimal.new(1_230_000_000_000_123_123),
        gas_price: Decimal.new(7_890_000_000_898_912_300_045),
        input: "0x000012",
        nonce: 99045,
        inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
        updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"),
        from_address: taft,
        to_address: lincoln
      )
      |> with_block(block, gas_used: Decimal.new(1_230_000_000_000_123_000), status: :ok)

    insert(:log, address: lincoln, index: 0, transaction: transaction)

    # From Lincoln to Taft.
    txn_from_lincoln =
      :transaction
      |> insert(from_address: lincoln, to_address: taft)
      |> with_block(block)

    internal = insert(:internal_transaction, index: 0, transaction: transaction)

    {:ok,
     %{
       pending: pending,
       pending_contract: pending_contract,
       internal: internal,
       lincoln: lincoln,
       taft: taft,
       transaction: transaction,
       txn_from_lincoln: txn_from_lincoln
     }}
  end

  test "search for transactions", %{session: session} do
    transaction = insert(:transaction, input: "0x736f636b73")

    session
    |> HomePage.visit_page()
    |> HomePage.search(to_string(transaction.hash))
    |> assert_has(TransactionPage.detail_hash(transaction))
  end

  describe "viewing transaction lists" do
    test "transactions on the home page", %{session: session} do
      session
      |> HomePage.visit_page()
      |> assert_has(HomePage.transactions(count: 5))
    end

    test "contract creation is shown for to_address on home page", %{session: session} do
      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_block()

      internal_transaction = insert(:internal_transaction_create, transaction: transaction, index: 0)

      session
      |> HomePage.visit_page()
      |> assert_has(HomePage.contract_creation(internal_transaction))
    end

    test "viewing the default transactions tab", %{session: session, transaction: transaction, pending: pending} do
      session
      |> TransactionListPage.visit_page()
      |> assert_has(TransactionListPage.transaction(transaction))
      |> assert_has(TransactionListPage.transaction_status(transaction))
      |> refute_has(TransactionListPage.transaction(pending))
    end

    test "viewing the pending tab", %{pending: pending, pending_contract: pending_contract, session: session} do
      session
      |> TransactionListPage.visit_page()
      |> TransactionListPage.click_pending()
      |> assert_has(TransactionListPage.transaction(pending))
      |> assert_has(TransactionListPage.transaction(pending_contract))
      |> assert_has(TransactionListPage.transaction_status(pending_contract))
    end

    test "contract creation is shown for to_address on list page", %{session: session} do
      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_block()

      insert(:internal_transaction_create, transaction: transaction, index: 0)

      session
      |> TransactionListPage.visit_page()
      |> assert_has(TransactionListPage.contract_creation(transaction))
    end
  end

  describe "viewing a transaction page" do
    @import_data [
      blocks: [
        params: [
          %{
            difficulty: 340_282_366_920_938_463_463_374_607_431_768_211_454,
            gas_limit: 6_946_336,
            gas_used: 50450,
            hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            nonce: 0,
            number: 565,
            parent_hash: "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
            size: 719,
            timestamp: Timex.parse!("2017-12-15T21:06:30.000000Z", "{ISO:Extended:Z}"),
            total_difficulty: 12_590_447_576_074_723_148_144_860_474_975_121_280_509
          }
        ]
      ],
      internal_transactions: [
        params: [
          %{
            call_type: "call",
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_677_320,
            gas_used: 27770,
            index: 0,
            output: "0x",
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            trace_address: [],
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "call",
            value: 0
          }
        ]
      ],
      logs: [
        params: [
          %{
            address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            data: "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
            first_topic: "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22",
            fourth_topic: nil,
            index: 0,
            second_topic: nil,
            third_topic: nil,
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "mined"
          }
        ]
      ],
      transactions: [
        on_conflict: :replace_all,
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
          }
        ]
      ],
      addresses: [
        params: [
          %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"},
          %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"}
        ]
      ]
    ]

    test "can navigate to transaction show from list page", %{session: session, transaction: transaction} do
      session
      |> TransactionListPage.visit_page()
      |> TransactionListPage.click_transaction(transaction)
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "can see a transaction's details", %{session: session, transaction: transaction} do
      session
      |> TransactionPage.visit_page(transaction)
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "can see a contract creation address in to_address", %{session: session} do
      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_block()

      internal_transaction = insert(:internal_transaction_create, transaction: transaction, index: 0)

      session
      |> TransactionPage.visit_page(transaction.hash)
      |> assert_has(TransactionPage.contract_creation_address_hash(internal_transaction))
    end

    test "can view a transaction's logs", %{session: session, transaction: transaction} do
      session
      |> TransactionPage.visit_page(transaction)
      |> TransactionPage.click_logs()
      |> assert_has(TransactionLogsPage.logs(count: 1))
    end

    test "can visit an address from the transaction logs page", %{
      lincoln: lincoln,
      session: session,
      transaction: transaction
    } do
      session
      |> TransactionLogsPage.visit_page(transaction)
      |> TransactionLogsPage.click_address(lincoln)
      |> assert_has(AddressPage.detail_hash(lincoln))
    end

    test "block confirmations via live update", %{session: session, transaction: transaction} do
      TransactionPage.visit_page(session, transaction)

      assert_text(session, TransactionPage.block_confirmations(), "0")

      Chain.import_blocks(@import_data)
      assert_text(session, TransactionPage.block_confirmations(), "10")
    end
  end
end
