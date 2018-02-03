defmodule Explorer.TransactionImporter do
  @moduledoc "Imports a transaction given a unique hash."

  import Ethereumex.HttpClient, only: [eth_get_transaction_by_hash: 1]

  alias Explorer.Address
  alias Explorer.Block
  alias Explorer.BlockTransaction
  alias Explorer.Repo
  alias Explorer.FromAddress
  alias Explorer.ToAddress
  alias Explorer.Transaction

  def import(hash) do
    raw_transaction = download_transaction(hash)
    changes = extract_attrs(raw_transaction)

    transaction = Repo.get_by(Transaction, hash: changes.hash) || %Transaction{}
    transaction
    |> Transaction.changeset(changes)
    |> Repo.insert_or_update!
    |> create_from_address(raw_transaction["from"])
    |> create_to_address(raw_transaction["to"] || raw_transaction["creates"])
    |> create_block_transaction(raw_transaction["blockHash"])
  end

  def download_transaction(hash) do
    {:ok, payload} = eth_get_transaction_by_hash(hash)
    payload
  end

  def extract_attrs(raw_transaction) do
    %{
      hash: raw_transaction["hash"],
      value: raw_transaction["value"] |> decode_integer_field,
      gas: raw_transaction["gas"] |> decode_integer_field,
      gas_price: raw_transaction["gasPrice"] |> decode_integer_field,
      input: raw_transaction["input"],
      nonce: raw_transaction["nonce"] |> decode_integer_field,
      public_key: raw_transaction["publicKey"],
      r: raw_transaction["r"],
      s: raw_transaction["s"],
      standard_v: raw_transaction["standardV"],
      transaction_index: raw_transaction["transactionIndex"],
      v: raw_transaction["v"],
    }
  end

  def create_block_transaction(transaction, block_hash) do
    block = Repo.get_by(Block, hash: block_hash)

    if block do
      block_transaction =
        Repo.get_by(BlockTransaction, transaction_id: transaction.id) ||
        %BlockTransaction{}

      changes = %{block_id: block.id, transaction_id: transaction.id}

      block_transaction
      |>BlockTransaction.changeset(changes)
      |> Repo.insert_or_update!
    end

    transaction
  end

  def create_from_address(transaction, hash) do
    address = Address.find_or_create_by_hash(hash)
    changes = %{transaction_id: transaction.id, address_id: address.id}

    from_address = Repo.get_by(FromAddress, changes) || %FromAddress{}
    from_address
    |> FromAddress.changeset(changes)
    |> Repo.insert_or_update!

    transaction
  end

  def create_to_address(transaction, hash) do
    address = Address.find_or_create_by_hash(hash)
    changes = %{transaction_id: transaction.id, address_id: address.id}

    to_address = Repo.get_by(ToAddress, changes) || %ToAddress{}
    to_address
    |> ToAddress.changeset(changes)
    |> Repo.insert_or_update!

    transaction
  end

  def decode_integer_field(hex) do
    {"0x", base_16} = String.split_at(hex, 2)
    String.to_integer(base_16, 16)
  end
end
