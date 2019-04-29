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

  describe "erc721_token_transfer/2" do
    test "finds token transfer" do
      from_address_hash = "0x7a30272c902563b712245696f0a81c5a0e45ddc8"
      to_address_hash = "0xb544cead8b660aae9f2e37450f7be2ffbc501793"
      from_address = insert(:address, hash: from_address_hash)
      to_address = insert(:address, hash: to_address_hash)
      block = insert(:block)

      transaction =
        insert(:transaction,
          input:
            "0x23b872dd0000000000000000000000007a30272c902563b712245696f0a81c5a0e45ddc8000000000000000000000000b544cead8b660aae9f2e37450f7be2ffbc5017930000000000000000000000000000000000000000000000000000000000000002",
          value: Decimal.new(0),
          created_contract_address_hash: nil
        )
        |> with_block(block, status: :ok)

      token_transfer =
        insert(:token_transfer, from_address: from_address, to_address: to_address, transaction: transaction)

      assert TransactionView.erc721_token_transfer(transaction, [token_transfer]) == token_transfer
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

      assert "1" == TransactionView.confirmations(transaction, block_height: block.number + 1)
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

      expected_value = "Max of 0.009 POA"
      assert expected_value == TransactionView.formatted_fee(transaction, denomination: :ether)
    end

    test "with fee" do
      {:ok, gas_price} = Wei.cast(3_000_000_000)
      transaction = build(:transaction, gas_price: gas_price, gas_used: Decimal.from_float(1_034_234.0))

      expected_value = "0.003102702 POA"
      assert expected_value == TransactionView.formatted_fee(transaction, denomination: :ether)
    end

    test "with fee but no available exchange_rate" do
    end
  end

  describe "formatted_status/1" do
    test "without block" do
      transaction =
        :transaction
        |> insert()
        |> Repo.preload(:block)

      status = TransactionView.transaction_status(transaction)
      assert TransactionView.formatted_status(status) == "Pending"
    end

    test "with block without status (pre-Byzantium/Ethereum Class)" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block, status: nil)

      status = TransactionView.transaction_status(transaction)
      assert TransactionView.formatted_status(status) == "(Awaiting internal transactions for status)"
    end

    test "with receipt with status :ok" do
      gas = 2

      transaction =
        :transaction
        |> insert(gas: gas)
        |> with_block(gas_used: gas - 1, status: :ok)

      status = TransactionView.transaction_status(transaction)
      assert TransactionView.formatted_status(status) == "Success"
    end

    test "with block with status :error without internal transactions indexed" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block, status: :error)

      status = TransactionView.transaction_status(transaction)
      assert TransactionView.formatted_status(status) == "Error: (Awaiting internal transactions for reason)"
    end

    test "with block with status :error with internal transactions indexed uses `error`" do
      transaction =
        :transaction
        |> insert()
        |> with_block(status: :error, internal_transactions_indexed_at: DateTime.utc_now(), error: "Out of Gas")

      status = TransactionView.transaction_status(transaction)
      assert TransactionView.formatted_status(status) == "Error: Out of Gas"
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
      token_transfers_path = "/page/0xSom3tH1ng/token_transfers/?additional_params=blah"
      internal_transactions_path = "/page/0xSom3tH1ng/internal_transactions/?additional_params=blah"
      logs_path = "/page/0xSom3tH1ng/logs/?additional_params=blah"

      assert TransactionView.current_tab_name(token_transfers_path) == "Token Transfers"
      assert TransactionView.current_tab_name(internal_transactions_path) == "Internal Transactions"
      assert TransactionView.current_tab_name(logs_path) == "Logs"
    end
  end
end
