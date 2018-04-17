defmodule Explorer.TransactionImporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Address, BlockTransaction, Transaction}
  alias Explorer.TransactionImporter

  @raw_transaction %{
    "creates" => nil,
    "hash" => "pepino",
    "value" => "0xde0b6b3a7640000",
    "from" => "0x34d0ef2c",
    "gas" => "0x21000",
    "gasPrice" => "0x10000",
    "input" => "0x5c8eff12",
    "nonce" => "0x31337",
    "publicKey" => "0xb39af9c",
    "r" => "0x9",
    "s" => "0x10",
    "to" => "0x7a33b7d",
    "standardV" => "0x11",
    "transactionIndex" => "0x12",
    "v" => "0x13"
  }

  @processed_transaction %{
    hash: "pepino",
    value: 1_000_000_000_000_000_000,
    gas: 135_168,
    gas_price: 65536,
    input: "0x5c8eff12",
    nonce: 201_527,
    public_key: "0xb39af9c",
    r: "0x9",
    s: "0x10",
    standard_v: "0x11",
    transaction_index: "0x12",
    v: "0x13"
  }

  describe "import/1" do
    test "imports and saves a transaction to the database" do
      use_cassette "transaction_importer_import_saves_the_transaction" do
        TransactionImporter.import("0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291")

        transaction = Transaction |> order_by(desc: :inserted_at) |> Repo.one()

        assert transaction.hash == "0xdc3a0dfd0bbffd5eabbe40fb13afbe35ac5f5c030bff148f3e50afe32974b291"
      end
    end

    test "when the transaction has previously been saved does not update it" do
      use_cassette "transaction_importer_updates_the_association" do
        insert(
          :transaction,
          hash: "0x170baac4eca26076953370dd603c68eab340c0135b19b585010d3158a5dbbf23",
          gas: 5
        )

        TransactionImporter.import("0x170baac4eca26076953370dd603c68eab340c0135b19b585010d3158a5dbbf23")

        transaction = Transaction |> order_by(desc: :inserted_at) |> Repo.one()

        assert transaction.gas == Decimal.new(5)
      end
    end

    test "binds an association to an existing block" do
      use_cassette "transaction_importer_saves_the_association" do
        block =
          insert(
            :block,
            hash: "0xfce13392435a8e7dab44c07d482212efb9dc39a9bea1915a9ead308b55a617f9"
          )

        TransactionImporter.import("0x64d851139325479c3bb7ccc6e6ab4cde5bc927dce6810190fe5d770a4c1ac333")

        transaction =
          Transaction
          |> Repo.get_by(hash: "0x64d851139325479c3bb7ccc6e6ab4cde5bc927dce6810190fe5d770a4c1ac333")

        block_transaction = BlockTransaction |> Repo.get_by(transaction_id: transaction.id)

        assert block_transaction.block_id == block.id
      end
    end

    test "when there is no block it does not save a block transaction" do
      use_cassette "transaction_importer_txn_without_block" do
        TransactionImporter.import("0xc6aa189827c14880f012a65292f7add7b5310094f8773a3d85b66303039b9dcf")

        transaction =
          Transaction
          |> Repo.get_by(hash: "0xc6aa189827c14880f012a65292f7add7b5310094f8773a3d85b66303039b9dcf")

        block_transaction = BlockTransaction |> Repo.get_by(transaction_id: transaction.id)

        refute block_transaction
      end
    end

    test "creates a from address" do
      use_cassette "transaction_importer_creates_a_from_address" do
        TransactionImporter.import("0xc445f5410912458c480d992dd93355ae3dad64d9f65db25a3cf43a9c609a2e0d")

        transaction =
          Transaction
          |> Repo.get_by(hash: "0xc445f5410912458c480d992dd93355ae3dad64d9f65db25a3cf43a9c609a2e0d")

        address = Address |> Repo.get_by(hash: "0xa5b4b372112ab8dbbb48c8d0edd89227e24ec785")

        assert transaction.from_address_id == address.id
      end
    end

    test "binds an existing from address" do
      insert(:address, hash: "0xa5b4b372112ab8dbbb48c8d0edd89227e24ec785")

      use_cassette "transaction_importer_creates_a_from_address" do
        TransactionImporter.import("0xc445f5410912458c480d992dd93355ae3dad64d9f65db25a3cf43a9c609a2e0d")

        transaction =
          Transaction
          |> Repo.get_by(hash: "0xc445f5410912458c480d992dd93355ae3dad64d9f65db25a3cf43a9c609a2e0d")

        address = Address |> Repo.get_by(hash: "0xa5b4b372112ab8dbbb48c8d0edd89227e24ec785")

        assert transaction.from_address_id == address.id
      end
    end

    test "creates a to address" do
      use_cassette "transaction_importer_creates_a_to_address" do
        TransactionImporter.import("0xdc533d4227734a7cacd75a069e8dc57ac571b865ed97bae5ea4cb74b54145f4c")

        transaction =
          Transaction
          |> Repo.get_by(hash: "0xdc533d4227734a7cacd75a069e8dc57ac571b865ed97bae5ea4cb74b54145f4c")

        address = Address |> Repo.get_by(hash: "0x24e5b8528fe83257d5fe3497ef616026713347f8")

        assert transaction.to_address_id == address.id
      end
    end

    test "binds an existing to address" do
      insert(:address, hash: "0x24e5b8528fe83257d5fe3497ef616026713347f8")

      use_cassette "transaction_importer_creates_a_to_address" do
        TransactionImporter.import("0xdc533d4227734a7cacd75a069e8dc57ac571b865ed97bae5ea4cb74b54145f4c")

        transaction =
          Transaction
          |> Repo.get_by(hash: "0xdc533d4227734a7cacd75a069e8dc57ac571b865ed97bae5ea4cb74b54145f4c")

        address = Address |> Repo.get_by(hash: "0x24e5b8528fe83257d5fe3497ef616026713347f8")

        assert(transaction.to_address_id == address.id)
      end
    end

    test "creates a to address using creates when to is nil" do
      use_cassette "transaction_importer_creates_a_to_address_from_creates" do
        TransactionImporter.import("0xdc533d4227734a7cacd75a069e8dc57ac571b865ed97bae5ea4cb74b54145f4c")

        transaction =
          Transaction
          |> Repo.get_by(hash: "0xdc533d4227734a7cacd75a069e8dc57ac571b865ed97bae5ea4cb74b54145f4c")

        address = Address |> Repo.get_by(hash: "0x24e5b8528fe83257d5fe3497ef616026713347f8")

        assert(transaction.to_address_id == address.id)
      end
    end

    test "processes a map of transaction attributes" do
      insert(:block, hash: "0xtakis")

      TransactionImporter.import(Map.merge(@raw_transaction, %{"hash" => "0xmunchos", "blockHash" => "0xtakis"}))

      last_transaction = Transaction |> order_by(desc: :inserted_at) |> limit(1) |> Repo.one()

      assert last_transaction.hash == "0xmunchos"
    end

    test "gets balances for addresses" do
      TransactionImporter.import("0xdc533d4227734a7cacd75a069e8dc57ac571b865ed97bae5ea4cb74b54145f4c")

      from_address = Address |> Repo.get_by(hash: "0xb2867180771b196518651c174c9240d5e8bd0ecd")
      to_address = Address |> Repo.get_by(hash: "0x24e5b8528fe83257d5fe3497ef616026713347f8")

      assert(from_address.balance == Decimal.new(1_572_374_181_095_000_000))
      assert(to_address.balance == Decimal.new(1_572_374_181_095_000_000))
    end
  end

  describe "find/1" do
    test "returns an empty transaction when there is no transaction with the given hash" do
      assert TransactionImporter.find("0xC001") == %Transaction{}
    end

    test "returns the transaction with the requested hash" do
      transaction = insert(:transaction, hash: "0xBEA75")
      assert TransactionImporter.find("0xBEA75").id == transaction.id
    end
  end

  describe "download_transaction/1" do
    test "downloads a transaction" do
      use_cassette "transaction_importer_download_transaction" do
        raw_transaction =
          TransactionImporter.download_transaction("0x170baac4eca26076953370dd603c68eab340c0135b19b585010d3158a5dbbf23")

        assert(raw_transaction["from"] == "0xbe96ef1d056c97323e210fd0dd818aa027e57143")
      end
    end

    test "when it has an invalid hash" do
      use_cassette "transaction_importer_download_transaction_with_a_bad_hash" do
        assert_raise MatchError, fn ->
          TransactionImporter.download_transaction("0xdecafisbadzzzz")
        end
      end
    end
  end

  describe "extract_attrs/1" do
    test "returns a changeset-friendly list of transaction attributes" do
      transaction_attrs = TransactionImporter.extract_attrs(@raw_transaction)
      assert transaction_attrs == @processed_transaction
    end
  end

  describe "create_block_transaction/2" do
    test "inserts a block transaction" do
      block = insert(:block)
      transaction = insert(:transaction)
      TransactionImporter.create_block_transaction(transaction, block.hash)

      block_transaction =
        BlockTransaction
        |> Repo.get_by(transaction_id: transaction.id, block_id: block.id)

      assert block_transaction
    end

    test "updates an already existing block transaction" do
      block = insert(:block)
      transaction = insert(:transaction)
      the_seventies = Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}")

      block_transaction =
        insert(:block_transaction, %{
          block_id: block.id,
          transaction_id: transaction.id,
          inserted_at: the_seventies,
          updated_at: the_seventies
        })

      update_block = insert(:block)
      TransactionImporter.create_block_transaction(transaction, update_block.hash)

      updated_block_transaction =
        BlockTransaction
        |> Repo.get_by(transaction_id: transaction.id)

      refute block_transaction.block_id == updated_block_transaction.block_id
      refute block_transaction.updated_at == updated_block_transaction.updated_at
    end
  end
end
