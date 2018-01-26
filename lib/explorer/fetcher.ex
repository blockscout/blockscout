defmodule Explorer.Fetcher  do
  alias Explorer.Block
  alias Explorer.Repo
  import Ethereumex.HttpClient, only: [eth_get_block_by_number: 2]

  @moduledoc false

  @dialyzer {:nowarn_function, fetch: 1}
  def fetch(block_number) do
    block_number
    |> download_block
    |> extract_block
    |> validate_block
    |> Repo.insert!
  end

  @dialyzer {:nowarn_function, download_block: 1}
  def download_block(block_number) do
    {:ok, block} = eth_get_block_by_number(block_number, true)
    block
  end

  def extract_block(block) do
    %{
      hash: block["hash"],
      number: block["number"] |> decode_integer_field,
      gas_used: block["gasUsed"] |> decode_integer_field,
      timestamp: block["timestamp"] |> decode_time_field,
      parent_hash: block["parentHash"],
      miner: block["miner"],
      difficulty: block["difficulty"] |> decode_integer_field,
      total_difficulty: block["totalDifficulty"] |> decode_integer_field,
      size: block["size"] |> decode_integer_field,
      gas_limit: block["gasLimit"] |> decode_integer_field,
      nonce: block["nonce"] || "0",
      transactions: block["transactions"] |> extract_transactions,
    }
  end

  def extract_transactions(transactions) do
    transactions |> Enum.map(&extract_transaction/1)
  end

  def extract_transaction(transaction) do
    %{
      hash: transaction["hash"],
      value: transaction["value"] |> decode_integer_field,
    }
  end

  def validate_block(block) do
    Block.changeset(%Block{}, block)
  end

  def decode_integer_field(hex) do
    {"0x", base_16} = String.split_at(hex, 2)
    String.to_integer(base_16, 16)
  end

  def decode_time_field(field) do
    field |> decode_integer_field |> Timex.from_unix
  end
end
