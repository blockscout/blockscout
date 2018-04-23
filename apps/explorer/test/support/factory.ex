defmodule Explorer.Factory do
  use ExMachina.Ecto, repo: Explorer.Repo

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
      nonce: sequence("block_nonce"),
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
    %InternalTransaction{
      call_type: Enum.random(["call", "creates", "calldelegate"]),
      from_address_hash: insert(:address).hash,
      gas: Enum.random(1..100_000),
      gas_used: Enum.random(1..100_000),
      index: Enum.random(0..9),
      input: sequence("0x"),
      output: sequence("0x"),
      to_address_hash: insert(:address).hash,
      trace_address: [Enum.random(0..4), Enum.random(0..4)],
      value: Enum.random(1..100_000)
    }
  end

  def log_factory do
    %Log{
      address_hash: insert(:address).hash,
      data: sequence("0x"),
      first_topic: nil,
      fourth_topic: nil,
      index: sequence(""),
      second_topic: nil,
      third_topic: nil,
      type: sequence("0x")
    }
  end

  def receipt_factory do
    %Receipt{
      cumulative_gas_used: Enum.random(21_000..100_000),
      gas_used: Enum.random(21_000..100_000),
      status: Enum.random(0..1),
      index: sequence("")
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

    block_transaction =
      transaction
      |> Explorer.Chain.Transaction.changeset(%{block_hash: block.hash, index: 0})
      |> Repo.update!()

    insert(:receipt, transaction_hash: hash)

    Repo.preload(block_transaction, [:block, :receipt])
  end
end
