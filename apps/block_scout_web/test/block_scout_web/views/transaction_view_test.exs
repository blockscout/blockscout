defmodule BlockScoutWeb.TransactionViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.Chain.Wei
  alias Explorer.Repo
  alias BlockScoutWeb.{BlockView, TransactionView}

  describe "block_number/1" do
    test "returns pending text for pending transaction" do
      pending = insert(:transaction)

      assert "Block Pending" == TransactionView.block_number(pending)
    end

    test "returns block number for collated transaction" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      assert [
               view_module: BlockView,
               partial: "_link.html",
               block: _block
             ] = TransactionView.block_number(transaction)
    end
  end

  describe "block_timestamp/1" do
    test "returns timestamp of transaction for pending transaction" do
      pending = insert(:transaction)

      assert pending.inserted_at == TransactionView.block_timestamp(pending)
    end

    test "returns timestamp for block for collacted transaction" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      assert block.timestamp == TransactionView.block_timestamp(transaction)
    end
  end

  describe "processing_time_duration/2" do
    test "returns :pending if the transaction has no block" do
      transaction = build(:transaction, block: nil)

      assert TransactionView.processing_time_duration(transaction) == :pending
    end

    test "returns :unknown if the transaction has no `earliest_processing_start`" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert(earliest_processing_start: nil)
        |> with_block(block)

      assert TransactionView.processing_time_duration(transaction) == :unknown
    end

    test "returns a single number when the timestamps are the same" do
      now = Timex.now()
      ten_seconds_ago = Timex.shift(now, seconds: -10)

      block = insert(:block, timestamp: now)

      transaction =
        :transaction
        |> insert(earliest_processing_start: ten_seconds_ago, inserted_at: ten_seconds_ago)
        |> with_block(block)

      assert TransactionView.processing_time_duration(transaction) == {:ok, "10 seconds"}
    end

    test "returns a range when the timestamps are not the same" do
      now = Timex.now()
      ten_seconds_ago = Timex.shift(now, seconds: -10)
      five_seconds_ago = Timex.shift(now, seconds: -5)

      block = insert(:block, timestamp: now)

      transaction =
        :transaction
        |> insert(earliest_processing_start: ten_seconds_ago, inserted_at: five_seconds_ago)
        |> with_block(block)

      assert TransactionView.processing_time_duration(transaction) == {:ok, "5-10 seconds"}
    end
  end

  describe "confirmations/2" do
    test "returns 0 if pending transaction" do
      transaction = build(:transaction, block: nil)

      assert 0 == TransactionView.confirmations(transaction, [])
    end

    test "returns string of number of blocks validated since subject block" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      assert "2" == TransactionView.confirmations(transaction, block_height: block.number + 1)
    end
  end

  describe "contract_creation?/1" do
    test "returns true if contract creation transaction" do
      assert TransactionView.contract_creation?(build(:transaction, to_address: nil))
    end

    test "returns false if not contract" do
      refute TransactionView.contract_creation?(build(:transaction))
    end
  end

  describe "formatted_fee/2" do
    test "pending transaction with no Receipt" do
      {:ok, gas_price} = Wei.cast(3_000_000_000)

      transaction =
        build(
          :transaction,
          gas: Decimal.new(3_000_000),
          gas_price: gas_price,
          gas_used: nil
        )

      expected_value = "Max of 0.009 ETH"
      assert expected_value == TransactionView.formatted_fee(transaction, denomination: :ether)
    end

    test "with fee" do
      {:ok, gas_price} = Wei.cast(3_000_000_000)
      transaction = build(:transaction, gas_price: gas_price, gas_used: Decimal.from_float(1_034_234.0))

      expected_value = "0.003102702 ETH"
      assert expected_value == TransactionView.formatted_fee(transaction, denomination: :ether)
    end
  end

  describe "formatted_result/1" do
    test "without block" do
      transaction =
        :transaction
        |> insert()
        |> Repo.preload(:block)

      status = TransactionView.transaction_status(transaction)
      assert TransactionView.formatted_result(status) == "Pending"
    end

    test "with block without status (pre-Byzantium/Ethereum Class)" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block, status: nil)

      status = TransactionView.transaction_status(transaction)
      assert TransactionView.formatted_result(status) == "(Awaiting internal transactions for status)"
    end

    test "with receipt with status :ok" do
      gas = 2

      transaction =
        :transaction
        |> insert(gas: gas)
        |> with_block(gas_used: gas - 1, status: :ok)

      status = TransactionView.transaction_status(transaction)
      assert TransactionView.formatted_result(status) == "Success"
    end

    test "with block with status :error without internal transactions indexed" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block, status: :error)

      insert(:pending_block_operation, block_hash: block.hash, fetch_internal_transactions: true)

      status = TransactionView.transaction_status(transaction)
      assert TransactionView.formatted_result(status) == "Error: (Awaiting internal transactions for reason)"
    end

    test "with block with status :error with internal transactions indexed uses `error`" do
      transaction =
        :transaction
        |> insert()
        |> with_block(status: :error, error: "Out of Gas")

      status = TransactionView.transaction_status(transaction)
      assert TransactionView.formatted_result(status) == "Error: Out of Gas"
    end
  end

  test "gas/1 returns the gas as a string" do
    assert "2" == TransactionView.gas(build(:transaction, gas: 2))
  end

  test "hash/1 returns the hash as a string" do
    assert "test" == TransactionView.hash(build(:transaction, hash: "test"))
  end

  describe "qr_code/1" do
    test "it returns an encoded value" do
      transaction = build(:transaction)
      assert {:ok, _} = Base.decode64(TransactionView.qr_code(transaction))
    end
  end

  describe "to_address_hash/1" do
    test "returns contract address for created contract transaction" do
      contract = insert(:contract_address)
      transaction = insert(:transaction, to_address: nil, created_contract_address: contract)
      assert contract.hash == TransactionView.to_address_hash(transaction)
    end

    test "returns hash for transaction" do
      transaction =
        :transaction
        |> insert(to_address: build(:address), created_contract_address: nil)
        |> Repo.preload([:created_contract_address, :to_address])

      assert TransactionView.to_address_hash(transaction) == transaction.to_address_hash
    end
  end

  describe "current_tab_name/1" do
    test "generates the correct tab name" do
      token_transfers_path = "/page/0xSom3tH1ng/token-transfers/?additional_params=blah"
      internal_transactions_path = "/page/0xSom3tH1ng/internal-transactions/?additional_params=blah"
      logs_path = "/page/0xSom3tH1ng/logs/?additional_params=blah"

      assert TransactionView.current_tab_name(token_transfers_path) == "Token Transfers"
      assert TransactionView.current_tab_name(internal_transactions_path) == "Internal Transactions"
      assert TransactionView.current_tab_name(logs_path) == "Logs"
    end
  end

  describe "aggregate_token_transfers/1" do
    test "aggregates token transfers" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer = insert(:token_transfer, transaction: transaction, amount: Decimal.new(1))

      result = TransactionView.aggregate_token_transfers([token_transfer, token_transfer, token_transfer])

      assert Enum.count(result.transfers) == 1
      assert List.first(result.transfers).amount == Decimal.new(3)
    end

    test "does not aggregate NFT tokens" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      token = insert(:token)

      token_transfer1 = insert(:token_transfer, transaction: transaction, token: token, token_ids: [1], amount: nil)
      token_transfer2 = insert(:token_transfer, transaction: transaction, token: token, token_ids: [2], amount: nil)
      token_transfer3 = insert(:token_transfer, transaction: transaction, token: token, token_ids: [3], amount: nil)

      result = TransactionView.aggregate_token_transfers([token_transfer1, token_transfer2, token_transfer3])

      assert Enum.count(result.transfers) == 3
      assert List.first(result.transfers).amount == nil
    end
  end
end
