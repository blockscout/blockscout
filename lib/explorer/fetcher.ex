defmodule Explorer.Fetcher  do
  @moduledoc false
  alias Explorer.Address
  alias Explorer.Block
  alias Explorer.FromAddress
  alias Explorer.Repo
  alias Explorer.ToAddress
  alias Explorer.Transaction
  import Ethereumex.HttpClient, only: [eth_get_block_by_number: 2]

  @dialyzer {:nowarn_function, fetch: 1}
  def fetch(block_number) do
    raw_block = block_number |> download_block

    Repo.transaction fn ->
      raw_block
      |> extract_block
      |> prepare_block
      |> Repo.insert!
      |> extract_transactions(raw_block["transactions"])
    end
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
    }
  end

  def extract_transactions(block, transactions) do
    Enum.map(transactions, fn(transaction) ->
      create_transaction(block, transaction)
    end)
  end

  def create_transaction(block, transaction) do
    %Transaction{}
    |> Transaction.changeset(extract_transaction(block, transaction))
    |> Repo.insert!
    |> create_from_address(transaction["from"])
    |> create_to_address(transaction["to"] || transaction["creates"])
  end

  def extract_transaction(block, transaction) do
    %{
      hash: transaction["hash"],
      value: transaction["value"] |> decode_integer_field,
      gas: transaction["gas"] |> decode_integer_field,
      gas_price: transaction["gasPrice"] |> decode_integer_field,
      input: transaction["input"],
      nonce: transaction["nonce"] |> decode_integer_field,
      public_key: transaction["publicKey"],
      r: transaction["r"],
      s: transaction["s"],
      standard_v: transaction["standardV"],
      transaction_index: transaction["transactionIndex"],
      v: transaction["v"],
      block_id: block.id,
    }
  end

  def create_to_address(transaction, hash) do
    address = Address.find_or_create_by_hash(hash)
    attrs = %{transaction_id: transaction.id, address_id: address.id}

    %ToAddress{}
    |> ToAddress.changeset(attrs)
    |> Repo.insert

    transaction
  end

  def create_from_address(transaction, hash) do
    address = Address.find_or_create_by_hash(hash)
    attrs = %{transaction_id: transaction.id, address_id: address.id}

    %FromAddress{}
    |> FromAddress.changeset(attrs)
    |> Repo.insert

    transaction
  end

  def prepare_block(block) do
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
