defmodule Explorer.Factory do
  use ExMachina.Ecto, repo: Explorer.Repo

  import Ecto.Query

  alias Explorer.Chain.{Address, Block, Hash, InternalTransaction, Log, Receipt, Transaction}
  alias Explorer.Repo

  @dialyzer {:nowarn_function, fields_for: 1}

  def address_factory do
    %Address{
      hash: address_hash()
    }
  end

  def address_hash do
    {:ok, address_hash} =
      "address_hash"
      |> sequence(& &1)
      |> Hash.Truncated.cast()

    address_hash
  end

  def block_factory do
    %Block{
      number: sequence("block_number", & &1),
      hash: block_hash(),
      parent_hash: block_hash(),
      nonce: sequence("block_nonce", & &1),
      miner_hash: insert(:address).hash,
      difficulty: Enum.random(1..100_000),
      total_difficulty: Enum.random(1..100_000),
      size: Enum.random(1..100_000),
      gas_limit: Enum.random(1..100_000),
      gas_used: Enum.random(1..100_000),
      timestamp: DateTime.utc_now()
    }
  end

  def block_hash do
    {:ok, block_hash} =
      "block_hash"
      |> sequence(& &1)
      |> Hash.Full.cast()

    block_hash
  end

  def internal_transaction_factory do
    type = internal_transaction_type()

    internal_transaction_factory(type)
  end

  # TODO add call, reward, and suicide
  def internal_transaction_type do
    Enum.random(~w(create)a)
  end

  def log_factory do
    %Log{
      address_hash: insert(:address).hash,
      data: sequence("0x"),
      first_topic: nil,
      fourth_topic: nil,
      index: 0,
      second_topic: nil,
      third_topic: nil,
      transaction_hash: insert(:transaction).hash,
      type: sequence("0x")
    }
  end

  def receipt_factory do
    %Receipt{
      cumulative_gas_used: Enum.random(21_000..100_000),
      gas_used: Enum.random(21_000..100_000),
      status: Enum.random(0..1)
    }
  end

  def transaction_factory do
    %Transaction{
      from_address_hash: insert(:address).hash,
      gas: Enum.random(21_000..100_000),
      gas_price: Enum.random(10..99) * 1_000_000_00,
      hash: transaction_hash(),
      input: sequence("0x"),
      nonce: Enum.random(1..1_000),
      public_key: sequence("0x"),
      r: sequence("0x"),
      s: sequence("0x"),
      standard_v: sequence("0x"),
      to_address_hash: insert(:address).hash,
      v: sequence("0x"),
      value: Enum.random(1..100_000)
    }
  end

  def transaction_hash do
    {:ok, transaction_hash} =
      "transaction_hash"
      |> sequence(& &1)
      |> Hash.Full.cast()

    transaction_hash
  end

  @doc """
  Validates the pending `transaction`(s) by add it to a `t:Explorer.Chain.Block.t/0` and giving it a `receipt`
  """

  def validate(transactions) when is_list(transactions) do
    Enum.map(transactions, &validate/1)
  end

  def validate(%Transaction{hash: hash} = transaction) do
    block = insert(:block)
    index = 0

    block_transaction =
      transaction
      |> Explorer.Chain.Transaction.changeset(%{block_hash: block.hash, index: index})
      |> Repo.update!()

    insert(:receipt, transaction_hash: hash, transaction_index: index)

    Repo.preload(block_transaction, [:block, :receipt])
  end

  def with_block(%Transaction{index: nil} = transaction, %Block{hash: block_hash}) do
    next_transaction_index = block_hash_to_next_transaction_index(block_hash)

    transaction
    |> Transaction.changeset(%{block_hash: block_hash, index: next_transaction_index})
    |> Repo.update!()
    |> Repo.preload(:block)
  end

  def with_receipt(%Transaction{hash: hash, index: index} = transaction) do
    insert(:receipt, transaction_hash: hash, transaction_index: index)

    Repo.preload(transaction, :receipt)
  end

  defp block_hash_to_next_transaction_index(block_hash) do
    query =
      from(
        transaction in Transaction,
        select: transaction.index,
        where: transaction.block_hash == ^block_hash
      )

    Repo.one!(query) + 1
  end

  defp integer_to_hexadecimal(integer) when is_integer(integer) do
    "0x" <> Integer.to_string(integer, 16)
  end

  defp internal_transaction_factory(:create = type) do
    gas = Enum.random(21_000..100_000)
    gas_used = Enum.random(0..gas)

    block = insert(:block)
    transaction = insert(:transaction, block_hash: block.hash, index: 0)
    receipt = insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)

    %InternalTransaction{
      created_contract_code: sequence("internal_transaction_created_contract_code", &integer_to_hexadecimal/1),
      created_contract_address_hash: insert(:address).hash,
      from_address_hash: insert(:address).hash,
      gas: gas,
      gas_used: gas_used,
      index: 0,
      # caller MUST suppy `index`
      init: sequence("internal_transaction_init", &integer_to_hexadecimal/1),
      trace_address: [],
      transaction_hash: receipt.transaction_hash,
      type: type,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end
end
