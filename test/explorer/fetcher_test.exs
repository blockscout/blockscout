defmodule Explorer.FetcherTest do
  use Explorer.DataCase

  alias Explorer.Block
  alias Explorer.Repo
  alias Explorer.Fetcher

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
  end

  describe "download_block/1" do
    test "returns a block for a given block number" do
      use_cassette "fetcher_download_block" do
        assert Fetcher.download_block("0x89923")["hash"] == "0x342878f5a2c06bc6146f9440910bab9c5ddae5dbd13c9a01d8adaf51ff5593ae"
      end
    end
  end

  describe "extract_block/1" do
    def raw_block(nonce \\ %{}) do
      Map.merge(%{
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
      }, nonce)
    end

    test "returns the struct of a block" do
      processed_block = %Block{
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
      assert Fetcher.extract_block(raw_block(%{"nonce" => "0xfb6e1a62d119228b"})) == processed_block
    end

    test "when there is no nonce" do
      assert Fetcher.extract_block(raw_block()).nonce == "0"
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
      use_cassette "fetcher_validate_block" do
        changeset = Fetcher.download_block("0x89923") |> Fetcher.extract_block |> Fetcher.validate_block
        assert(changeset.valid?)
      end
    end
  end
end
