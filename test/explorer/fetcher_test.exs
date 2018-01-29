defmodule Explorer.FetcherTest do
  use Explorer.DataCase

  alias Explorer.Block
  alias Explorer.Repo
  alias Explorer.Fetcher
  alias Explorer.Transaction

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
    transactions: [],
  }

  @raw_transaction %{
    "block_id" => "1",
    "hash" => "pepino",
    "value" => "0xde0b6b3a7640000",
    "gas" => "0x21000",
    "gasPrice" => "0x10000",
    "input" => "0x5c8eff12",
    "nonce" => "0x31337",
    "publicKey" => "0xb39af9c",
    "r" => "0x9",
    "s" => "0x10",
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
  }

  describe "fetch/1" do
    test "the latest block is copied over from the blockchain" do
      use_cassette "fetcher_fetch" do
        Fetcher.fetch("0x89923")

        last_block = Block
          |> order_by(desc: :inserted_at)
          |> limit(1)
          |> Repo.all
          |> List.first

        assert last_block.number == 563491
      end
    end

    test "when the block has a transaction it should be created" do
      use_cassette "fetcher_fetch_with_transaction" do
        Fetcher.fetch("0x8d2a8")

        last_transaction = Transaction
          |> order_by(desc: :inserted_at)
          |> limit(1)
          |> Repo.all
          |> List.first

        assert last_transaction.value == Decimal.new(1000000000000000000)
        assert last_transaction.hash == "0x8cea0c5ffdd96a4dada74066f7416a0957dca278d45a1caec439ba68cbf3f4d6"
      end
    end

    test "when the block has a transaction with zero value it should store that zero value" do
      use_cassette "fetcher_fetch_with_a_zero_value_transaction" do
        Fetcher.fetch("0x918c1")

        last_transaction = Transaction
          |> order_by(desc: :inserted_at)
          |> limit(1)
          |> Repo.all
          |> List.first

        assert last_transaction.value == Decimal.new(0)
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

    test "when there is a transaction" do
      assert Fetcher.extract_block(@raw_block).transactions
    end
  end

  describe "extract_transactions/1" do
    test "that it parses a list of transactions" do
      transactions = Fetcher.extract_transactions([@raw_transaction])
      assert transactions == [@processed_transaction]
    end
  end

  describe "extract_transaction/1" do
    test "that it extracts the transaction" do
      assert Fetcher.extract_transaction(@raw_transaction) == @processed_transaction
    end

    test "when the transaction value is zero it returns a decimal" do
      transaction = %{@raw_transaction | "value" => "0x0"}
      assert Fetcher.extract_transaction(transaction).value == 0
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

  describe "validate_block/1" do
    test "returns a valid changeset for an extracted block" do
      changeset = @raw_block |> Fetcher.extract_block |> Fetcher.validate_block
      assert changeset.valid?
    end

    test "that it puts a nested transaction into a changeset" do
      block = %{@raw_block | "transactions" => [@raw_transaction]}
      changeset = block |> Fetcher.extract_block |> Fetcher.validate_block
      first_transaction = changeset.changes.transactions |> List.first
      assert first_transaction.changes.hash == "pepino"
    end

    test "that it validates a nested transaction" do
      transaction = %{@raw_transaction | "hash" => ""}
      block = %{@raw_block | "transactions" => [transaction]}
      changeset = block |> Fetcher.extract_block |> Fetcher.validate_block
      transaction_changeset = changeset.changes.transactions |> List.first
      assert transaction_changeset.errors[:hash] == {"can't be blank", [validation: :required]}
    end
  end
end
