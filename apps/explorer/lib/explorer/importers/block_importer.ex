defmodule Explorer.BlockImporter do
  @moduledoc "Imports a block."

  import Ecto.Query
  import Ethereumex.HttpClient, only: [eth_get_block_by_number: 2]

  alias Explorer.Block
  alias Explorer.Ethereum
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Workers.ImportTransaction

  def import(raw_block) when is_map(raw_block) do
    changes = extract_block(raw_block)
    block = changes.hash |> find()

    if is_nil(block.id), do: block |> Block.changeset(changes) |> Repo.insert()

    Enum.map(raw_block["transactions"], &ImportTransaction.perform/1)
  end

  @dialyzer {:nowarn_function, import: 1}
  def import("pending") do
    raw_block = download_block("pending")
    Enum.map(raw_block["transactions"], &ImportTransaction.perform_later/1)
  end

  @dialyzer {:nowarn_function, import: 1}
  def import(block_number) do
    alias Explorer.BlockImporter
    block_number |> download_block() |> BlockImporter.import()
  end

  def find(hash) do
    query =
      from(
        b in Block,
        where: fragment("lower(?)", b.hash) == ^String.downcase(hash),
        limit: 1
      )

    query |> Repo.one() || %Block{}
  end

  @dialyzer {:nowarn_function, download_block: 1}
  def download_block(block_number) do
    {:ok, block} =
      block_number
      |> encode_number()
      |> eth_get_block_by_number(true)

    block
  end

  def extract_block(raw_block) do
    %{
      hash: raw_block["hash"],
      number: raw_block["number"] |> Ethereum.decode_integer_field(),
      gas_used: raw_block["gasUsed"] |> Ethereum.decode_integer_field(),
      timestamp: raw_block["timestamp"] |> Ethereum.decode_time_field(),
      parent_hash: raw_block["parentHash"],
      miner: raw_block["miner"],
      difficulty: raw_block["difficulty"] |> Ethereum.decode_integer_field(),
      total_difficulty: raw_block["totalDifficulty"] |> Ethereum.decode_integer_field(),
      size: raw_block["size"] |> Ethereum.decode_integer_field(),
      gas_limit: raw_block["gasLimit"] |> Ethereum.decode_integer_field(),
      nonce: raw_block["nonce"] || "0"
    }
  end

  defp encode_number("latest"), do: "latest"
  defp encode_number("earliest"), do: "earliest"
  defp encode_number("pending"), do: "pending"
  defp encode_number("0x" <> number) when is_binary(number), do: number

  defp encode_number(number) when is_binary(number) do
    number
    |> String.to_integer()
    |> encode_number()
  end

  defp encode_number(number), do: "0x" <> Integer.to_string(number, 16)
end
