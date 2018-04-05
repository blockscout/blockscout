defmodule Explorer.TransactionImporter do
  @moduledoc "Imports a transaction given a unique hash."

  import Ecto.Query
  import Ethereumex.HttpClient, only: [eth_get_transaction_by_hash: 1]

  alias Explorer.{Chain, Ethereum, Repo, BalanceImporter}
  alias Explorer.Chain.{Block, BlockTransaction, Transaction}

  def import(hash) when is_binary(hash) do
    hash |> download_transaction() |> persist_transaction()
  end

  def import(raw_transaction) when is_map(raw_transaction) do
    persist_transaction(raw_transaction)
  end

  def persist_transaction(raw_transaction) do
    found_transaction = raw_transaction["hash"] |> find()

    transaction =
      case is_nil(found_transaction.id) do
        false ->
          found_transaction

        true ->
          to_address =
            raw_transaction
            |> to_address()
            |> fetch_address()

          from_address =
            raw_transaction
            |> from_address()
            |> fetch_address()

          changes =
            raw_transaction
            |> extract_attrs()
            |> Map.put(:to_address_id, to_address.id)
            |> Map.put(:from_address_id, from_address.id)

          found_transaction |> Transaction.changeset(changes) |> Repo.insert!()
      end

    transaction
    |> create_block_transaction(raw_transaction["blockHash"])

    refresh_account_balances(raw_transaction)

    transaction
  end

  def find(hash) do
    query =
      from(
        t in Transaction,
        where: fragment("lower(?)", t.hash) == ^String.downcase(hash),
        limit: 1
      )

    query |> Repo.one() || %Transaction{}
  end

  def download_transaction(hash) do
    {:ok, payload} = eth_get_transaction_by_hash(hash)
    payload
  end

  def extract_attrs(raw_transaction) do
    %{
      hash: raw_transaction["hash"],
      value: raw_transaction["value"] |> Ethereum.decode_integer_field(),
      gas: raw_transaction["gas"] |> Ethereum.decode_integer_field(),
      gas_price: raw_transaction["gasPrice"] |> Ethereum.decode_integer_field(),
      input: raw_transaction["input"],
      nonce: raw_transaction["nonce"] |> Ethereum.decode_integer_field(),
      public_key: raw_transaction["publicKey"],
      r: raw_transaction["r"],
      s: raw_transaction["s"],
      standard_v: raw_transaction["standardV"],
      transaction_index: raw_transaction["transactionIndex"],
      v: raw_transaction["v"]
    }
  end

  def create_block_transaction(transaction, hash) do
    query =
      from(
        t in Block,
        where: fragment("lower(?)", t.hash) == ^String.downcase(hash),
        limit: 1
      )

    block = query |> Repo.one()

    if block do
      changes = %{block_id: block.id, transaction_id: transaction.id}

      case Repo.get_by(BlockTransaction, transaction_id: transaction.id) do
        nil ->
          %BlockTransaction{}
          |> BlockTransaction.changeset(changes)
          |> Repo.insert()

        block_transaction ->
          block_transaction
          |> BlockTransaction.changeset(%{block_id: block.id})
          |> Repo.update()
      end
    end

    transaction
  end

  def to_address(%{"to" => to}) when not is_nil(to), do: to
  def to_address(%{"creates" => creates}) when not is_nil(creates), do: creates
  def to_address(hash) when is_bitstring(hash), do: hash

  def from_address(%{"from" => from}), do: from
  def from_address(hash) when is_bitstring(hash), do: hash

  def fetch_address(hash) when is_bitstring(hash) do
    {:ok, address} = Chain.ensure_hash_address(hash)

    address
  end

  defp refresh_account_balances(raw_transaction) do
    raw_transaction
    |> to_address()
    |> update_balance()

    raw_transaction
    |> from_address()
    |> update_balance()
  end

  defp update_balance(address_hash) do
    BalanceImporter.import(address_hash)
  end
end
