defmodule Mix.Tasks.Scrape do
  use Mix.Task
  alias Explorer.Block
  alias Explorer.Repo
  import Ethereumex.HttpClient, only: [
    eth_block_number: 0,
    eth_get_block_by_number: 2
  ]

  @shortdoc "Scrape the blockchain."
  @moduledoc false

  def run(_) do
    persist()
  end

  def persist do
    {:ok, _} = Repo.insert(changeset())
  end

  def changeset do
    Block.changeset(attributes(), %{})
  end

  def attributes do
    %Block{
      hash: hash(),
      number: number(),
      timestamp: timestamp(),
      gas_used: gas_used(),
      parent_hash: "0x0",
      nonce: "0",
      miner: "0x0",
      difficulty: "0",
      total_difficulty: "0",
      size: "0",
      gas_limit: "0",
    }
  end

  def hash do
    latest_block()["hash"]
  end

  def number do
    decode_integer_field(latest_block()["number"])
  end

  def timestamp do
    epoch_to_datetime(decode_integer_field(latest_block()["timestamp"]))
  end

  def gas_used do
    decode_integer_field(latest_block()["gasUsed"])
  end

  def latest_block do
    Mix.Task.run "app.start"
    {:ok, latest_block_number} = eth_block_number()
    {:ok, latest_block} = eth_get_block_by_number(latest_block_number, true)
    latest_block
  end

  def decode_integer_field(field) do
    {"0x", base_16} = String.split_at(field, 2)
    String.to_integer(base_16, 16)
  end

  def epoch_to_datetime(epoch) do
    Timex.from_unix(epoch)
  end
end
