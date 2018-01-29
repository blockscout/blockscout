defmodule Explorer.FetcherTest do
  use Explorer.DataCase

  alias Explorer.Block
  alias Explorer.Repo
  alias Explorer.Fetcher
  alias Explorer.Transaction
  alias Explorer.Address
  alias Explorer.ToAddress
  alias Explorer.FromAddress

  @raw_block %{
    "difficulty" => "0xfffffffffffffffffffffffffffffffe",
    "gasLimit" => "0x02",
    "gasUsed" => "0x19522",
    "hash" => "bananas",
    "miner" => "0xdb1207770e0a4258d7a4ce49ab037f92564fea85",
    "number" => "0x7f2fb",
    "parentHash" => "0x70029f66ea5a3b2b1ede95079d95a2ab74b649b5b17cdcf6f29b6317e7c7efa6",
    "size" => "0x10",
    "timestamp" => "0x12",
    "totalDifficulty" => "0xff",
    "nonce" => nil,
    "transactions" => []
  }

  @processed_block %{
    difficulty: 340282366920938463463374607431768211454,
    gas_limit: 2,
    gas_used: 103714,
    hash: "bananas",
    nonce: "0xfb6e1a62d119228b",
    miner: "0xdb1207770e0a4258d7a4ce49ab037f92564fea85",
    number: 520955,
    parent_hash: "0x70029f66ea5a3b2b1ede95079d95a2ab74b649b5b17cdcf6f29b6317e7c7efa6",
    size: 16,
    timestamp: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
    total_difficulty: 255,
  }

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
    "v" => "0x13",
  }

  @processed_transaction %{
    hash: "pepino",
    value: 1000000000000000000,
    gas: 135168,
    gas_price: 65536,
    input: "0x5c8eff12",
    nonce: 201527,
    public_key: "0xb39af9c",
    r: "0x9",
    s: "0x10",
    standard_v: "0x11",
    transaction_index: "0x12",
    v: "0x13",
    block_id: 100,
  }

  describe "fetch/1" do
    test "the latest block is copied over from the blockchain" do
      use_cassette "fetcher_fetch" do
        Fetcher.fetch("0x89923")
        last_block = Block |> order_by(desc: :inserted_at) |> Repo.one
        assert last_block.number == 563491
      end
    end

    test "when the block has a transaction it should be created" do
      use_cassette "fetcher_fetch_with_transaction" do
        Fetcher.fetch("0x8d2a8")
        last_transaction = Transaction |> order_by(desc: :inserted_at) |> Repo.one
        assert last_transaction.value == Decimal.new(1000000000000000000)
        assert last_transaction.hash == "0x8cea0c5ffdd96a4dada74066f7416a0957dca278d45a1caec439ba68cbf3f4d6"
      end
    end

    test "when the block has a transaction with zero value it should store that zero value" do
      use_cassette "fetcher_fetch_with_a_zero_value_transaction" do
        Fetcher.fetch("0x918c1")
        last_transaction = Transaction |> order_by(desc: :inserted_at) |> Repo.one
        assert last_transaction.value == Decimal.new(0)
      end
    end

    test "When the block has a transaction that it creates an associated 'to address'" do
      use_cassette "fetcher_fetch_with_transaction_for_address" do
        Fetcher.fetch("0x8d2a8")

        query = from address in Explorer.Address,
          join: to_address in Explorer.ToAddress, where: to_address.address_id == address.id,
          join: transaction in Transaction, where: transaction.id == to_address.transaction_id

        assert Repo.one(query).hash == "0xb7cffe2ac19b9d5705a24cbe14fef5663af905a6"
      end
    end

    test "When the block has a transaction that it creates an associated 'from address'" do
      use_cassette "fetcher_fetch_with_transaction_for_address" do
        Fetcher.fetch("0x8d2a8")

        query = from address in Explorer.Address,
          join: from_address in Explorer.FromAddress, where: from_address.address_id == address.id,
          join: transaction in Transaction, where: transaction.id == from_address.transaction_id

        assert Repo.one(query).hash == "0x9a4a90e2732f3fa4087b0bb4bf85c76d14833df1"
      end
    end
  end

  describe "download_block/1" do
    test "returns a block for a given block number" do
      use_cassette "fetcher_download_block" do
        assert Fetcher.download_block("0x89923")["hash"] == "0x342878f5a2c06bc6146f9440910bab9c5ddae5dbd13c9a01d8adaf51ff5593ae"
      end
    end
  end

  describe "extract_block/1" do
    test "returns the struct of a block" do
      assert Fetcher.extract_block(%{@raw_block | "nonce" => "0xfb6e1a62d119228b"}) == @processed_block
    end

    test "when there is no nonce" do
      assert Fetcher.extract_block(@raw_block).nonce == "0"
    end
  end

  describe "extract_transactions/2" do
    test "that it creates a list of transactions" do
      block = insert(:block, %{id: 100})
      transactions = Fetcher.extract_transactions(block, [@raw_transaction])
      assert List.first(transactions).block_id == 100
    end
  end

  describe "create_transaction/2" do
    test "that it creates a transaction" do
      block = insert(:block)
      transaction_attrs = %{@raw_transaction | "hash" => "0xab1"}
      Fetcher.create_transaction(block, transaction_attrs)
      last_transaction = Transaction |> order_by(desc: :inserted_at) |> Repo.one
      assert last_transaction.hash == "0xab1"
    end

    test "that it creates a 'to address'" do
      block = insert(:block)
      transaction_attrs = %{@raw_transaction | "to" => "0xSmoothiesRGr8"}
      Fetcher.create_transaction(block, transaction_attrs)
      assert Repo.get_by(Address, hash: "0xsmoothiesrgr8")
    end

    test "it creates a 'to address' from 'creates' when 'to' is nil" do
      block = insert(:block)
      transaction_attrs = %{@raw_transaction | "creates" => "0xSmoothiesRGr8", "to" => nil}
      Fetcher.create_transaction(block, transaction_attrs)
      last_address = Repo.get_by(Address, hash: "0xsmoothiesrgr8")
      assert last_address
    end

    test "that it creates a relation for the transaction and 'to address'" do
      block = insert(:block)
      Fetcher.create_transaction(block, @raw_transaction)
      transaction = Repo.get_by(Transaction, hash: "pepino")
      address = Repo.get_by(Address, hash: "0x7a33b7d")
      assert Repo.get_by(ToAddress, %{transaction_id: transaction.id, address_id: address.id})
    end

    test "that it creates a 'from address'" do
      block = insert(:block)
      transaction_attrs = %{@raw_transaction | "from" => "0xSmurfsRool"}
      Fetcher.create_transaction(block, transaction_attrs)
      assert Repo.get_by(Address, hash: "0xsmurfsrool")
    end
  end

  describe "create_to_address/2" do
    test "that it creates a new address when one does not exist" do
      transaction = insert(:transaction)
      Fetcher.create_to_address(transaction, "0xFreshPrince")
      last_address = Address |> order_by(desc: :inserted_at) |> Repo.one
      assert last_address.hash == "0xfreshprince"
    end

    test "that it creates a relation for the transaction and address" do
      transaction = insert(:transaction)
      Fetcher.create_to_address(transaction, "0xFreshPrince")
      address = Address |> order_by(desc: :inserted_at) |> Repo.one
      to_address = ToAddress |> order_by(desc: :inserted_at)|> Repo.one
      assert to_address.transaction_id == transaction.id
      assert to_address.address_id == address.id
    end

    test "when the address already exists it doesn't insert a new address" do
      transaction = insert(:transaction)
      insert(:address, %{hash: "bigmouthbillybass"})
      Fetcher.create_to_address(transaction, "bigmouthbillybass")
      assert Address |> Repo.all |> length == 1
    end
  end

  describe "create_from_address/2" do
    test "that it creates a new address when one does not exist" do
      transaction = insert(:transaction)
      Fetcher.create_from_address(transaction, "0xbb8")
      last_address = Address |> order_by(desc: :inserted_at) |> Repo.one
      assert last_address.hash == "0xbb8"
    end

    test "that it creates a relation for the transaction and 'from address'" do
      block = insert(:block)
      Fetcher.create_transaction(block, @raw_transaction)
      transaction = Repo.get_by(Transaction, hash: "pepino")
      address = Repo.get_by(Address, hash: "0x34d0ef2c")
      assert Repo.get_by(FromAddress, %{transaction_id: transaction.id, address_id: address.id})
    end

    test "when the address already exists it doesn't insert a new address" do
      transaction = insert(:transaction)
      insert(:address, %{hash: "0xbb8"})
      Fetcher.create_from_address(transaction, "0xbb8")
      assert Address |> Repo.all |> length == 1
    end
  end

  describe "extract_transaction/2" do
    test "that it extracts the transaction" do
      assert Fetcher.extract_transaction(%{id: 100}, @raw_transaction) == @processed_transaction
    end

    test "when the transaction value is zero it returns a decimal" do
      transaction = %{@raw_transaction | "value" => "0x0"}
      assert Fetcher.extract_transaction(%{id: 100}, transaction).value == 0
    end
  end

  describe "decode_integer_field/1" do
    test "returns the integer value of a hex value" do
      assert(Fetcher.decode_integer_field("0x7f2fb") == 520955)
    end
  end

  describe "decode_time_field/1" do
    test "returns the date value of a hex value" do
      the_seventies = Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}")
      assert(Fetcher.decode_time_field("0x12") == the_seventies)
    end
  end

  describe "prepare_block/1" do
    test "returns a valid changeset for an extracted block" do
      changeset = @raw_block |> Fetcher.extract_block |> Fetcher.prepare_block
      assert changeset.valid?
    end
  end
end
