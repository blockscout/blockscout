defmodule Explorer.TransactionImporter do
  @moduledoc "Imports a transaction given a unique hash."

  import Ecto.Query
  import Ethereumex.HttpClient, only: [eth_get_transaction_by_hash: 1]

  alias Explorer.Address
  alias Explorer.Block
  alias Explorer.BlockTransaction
  alias Explorer.Repo
  alias Explorer.FromAddress
  alias Explorer.ToAddress
  alias Explorer.Transaction

  def import(hash) when is_binary(hash) do
    hash |> download_transaction() |> persist_transaction()
  end

  def import(raw_transaction) when is_map(raw_transaction) do
    persist_transaction(raw_transaction)
  end

  def persist_transaction(raw_transaction) do
    changes = extract_attrs(raw_transaction)
    found_transaction = changes.hash |> find()

    transaction = case is_nil(found_transaction.id) do
      true ->
        found_transaction |> Transaction.changeset(changes) |> Repo.insert!
      false -> found_transaction
    end

    to_address = raw_transaction["to"] || raw_transaction["creates"]
    transaction
    |> create_from_address(raw_transaction["from"])
    |> create_to_address(to_address)
    |> create_block_transaction(raw_transaction["blockHash"])
  end

  def find(hash) do
    query = from t in Transaction,
      where: fragment("lower(?)", t.hash) == ^String.downcase(hash),
      limit: 1
    (query |> Repo.one()) || %Transaction{}
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

  def create_block_transaction(transaction, hash) do
    query = from t in Block,
      where: fragment("lower(?)", t.hash) == ^String.downcase(hash),
      limit: 1
    block = query |> Repo.one()

    if block do
      changes = %{block_id: block.id, transaction_id: transaction.id}
      case Repo.get_by(BlockTransaction, transaction_id: transaction.id) do
        nil ->
          %BlockTransaction{}
          |> BlockTransaction.changeset(changes)
          |> Repo.insert
        block_transaction ->
          block_transaction
          |> BlockTransaction.changeset(%{block_id: block.id})
          |> Repo.update
      end
    end

    transaction
  end

  def create_from_address(transaction, hash) do
    address = Address.find_or_create_by_hash(hash)
    changes = %{address_id: address.id, transaction_id: transaction.id}

    case Repo.get_by(FromAddress, transaction_id: transaction.id) do
      nil ->
        %FromAddress{}
        |> FromAddress.changeset(changes)
        |> Repo.insert
      from_address ->
        from_address
        |> FromAddress.changeset(%{address_id: address.id})
        |> Repo.update
    end

    transaction
  end

  def create_to_address(transaction, hash) do
    address = Address.find_or_create_by_hash(hash)
    changes = %{address_id: address.id, transaction_id: transaction.id}

    case Repo.get_by(ToAddress, transaction_id: transaction.id) do
      nil ->
        %ToAddress{}
        |> ToAddress.changeset(changes)
        |> Repo.insert
      to_address ->
        to_address
        |> ToAddress.changeset(%{address_id: address.id})
        |> Repo.update
    end

    transaction
  end

  def decode_integer_field(hex) do
    {"0x", base_16} = String.split_at(hex, 2)
    String.to_integer(base_16, 16)
  end
end
