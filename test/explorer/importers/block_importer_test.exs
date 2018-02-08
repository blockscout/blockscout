defmodule Explorer.BlockImporterTest do
  use Explorer.DataCase

  import Mock

  alias Explorer.Block
  alias Explorer.BlockImporter
  alias Explorer.Transaction
  alias Explorer.Workers.ImportTransaction

  describe "import/1" do
    test "imports and saves a block to the database" do
      use_cassette "block_importer_import_1_saves_the_block" do
        with_mock ImportTransaction, [perform_later: fn(block) -> block end] do
          BlockImporter.import("0xc4f0d")
          block = Block |> order_by(desc: :inserted_at) |> Repo.one()

          assert block.hash == "0x16cb43ccfb7875c14eb3f03bdc098e4af053160544270594fa429d256cbca64e"
        end
      end
    end

    test "when a block with the same hash is imported it updates the block" do
      use_cassette "block_importer_import_1_duplicate_block" do
        with_mock ImportTransaction, [perform_later: fn(hash) -> insert(:transaction, hash: hash) end] do
          insert(:block, hash: "0x16cb43ccfb7875c14eb3f03bdc098e4af053160544270594fa429d256cbca64e", gas_limit: 5)
          BlockImporter.import("0xc4f0d")
          block = Repo.get_by(Block, hash: "0x16cb43ccfb7875c14eb3f03bdc098e4af053160544270594fa429d256cbca64e")

          assert block.gas_limit == 8000000
          assert Block |> Repo.all |> Enum.count == 1
        end
      end
    end
  end

  describe "find/1" do
    test "returns an empty block when there is no block with the given hash" do
      assert BlockImporter.find("0xC001") == %Block{}
    end

    test "returns the block with the requested hash" do
      block = insert(:block, hash: "0xBEA75")
      assert BlockImporter.find("0xBEA75").id == block.id
    end
  end

  describe "download_block/1" do
    test "downloads the block" do
      use_cassette "block_importer_download_block_1_downloads_the_block" do
        raw_block = BlockImporter.download_block("0xc4f0d")
        assert raw_block
      end
    end
  end

  describe "extract_block/1" do
    test "extracts the block attributes" do
      extracted_block = BlockImporter.extract_block(%{
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
        "nonce" => "0xfb6e1a62d119228b",
        "transactions" => []
      })

      assert(extracted_block == %{
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
      })
    end
  end

  describe "import_transactions/1" do
    test "it enqueues workers that download each transaction" do
      with_mock ImportTransaction, [perform_later: fn(hash) -> insert(:transaction, hash: hash) end] do
        queue = BlockImporter.import_transactions([
          "0x004bda8224214d277fc41be030fc55109afc662c5a87236de8990c8589f1c7b6",
          "0x31d59a001b870543c2b34618aecfa8846f7c3e50e9e267119670b311c086db99",
        ])
        last_transaction = Transaction |> order_by(desc: :inserted_at) |> limit(1) |> Repo.one

        assert last_transaction.hash == "0x004bda8224214d277fc41be030fc55109afc662c5a87236de8990c8589f1c7b6"
        assert queue |> Enum.count == 2
      end
    end
  end

  describe "decode_integer_field/1" do
    test "returns the integer value of a hex value" do
      assert(BlockImporter.decode_integer_field("0x7f2fb") == 520955)
    end
  end

  describe "decode_time_field/1" do
    test "returns the date value of a hex value" do
      the_seventies = Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}")
      assert(BlockImporter.decode_time_field("0x12") == the_seventies)
    end
  end
end
