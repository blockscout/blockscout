defmodule Explorer.Factory do
  use ExMachina.Ecto, repo: Explorer.Repo

  require Ecto.Query

  import Ecto.Query
  import Kernel, except: [+: 2]

  alias Explorer.Chain.Block.{Range, Reward}

  alias Explorer.Chain.{
    Address,
    Block,
    Data,
    Hash,
    InternalTransaction,
    Log,
    Transaction
  }

  alias Explorer.Market.MarketHistory
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

  def with_block(%Transaction{index: nil} = transaction) do
    with_block(transaction, insert(:block))
  end

  def with_block(transactions) when is_list(transactions) do
    block = insert(:block)
    with_block(transactions, block)
  end

  def with_block(%Transaction{} = transaction, %Block{} = block) do
    with_block(transaction, block, [])
  end

  def with_block(transactions, %Block{} = block) when is_list(transactions) do
    Enum.map(transactions, &with_block(&1, block))
  end

  def with_block(%Transaction{index: nil} = transaction, collated_params) when is_list(collated_params) do
    block = insert(:block)
    with_block(transaction, block, collated_params)
  end

  def with_block(
        %Transaction{index: nil} = transaction,
        %Block{hash: block_hash, number: block_number},
        collated_params
      )
      when is_list(collated_params) do
    next_transaction_index = block_hash_to_next_transaction_index(block_hash)

    cumulative_gas_used = collated_params[:cumulative_gas_used] || Enum.random(21_000..100_000)
    gas_used = collated_params[:gas_used] || Enum.random(21_000..100_000)
    internal_transactions_indexed_at = collated_params[:internal_transactions_indexed_at]
    status = collated_params[:status] || Enum.random(0..1)

    transaction
    |> Transaction.changeset(%{
      block_hash: block_hash,
      block_number: block_number,
      cumulative_gas_used: cumulative_gas_used,
      gas_used: gas_used,
      index: next_transaction_index,
      internal_transactions_indexed_at: internal_transactions_indexed_at,
      status: status
    })
    |> Repo.update!()
    |> Repo.preload(:block)
  end

  def data(sequence_name) do
    unpadded =
      sequence_name
      |> sequence(& &1)
      |> Integer.to_string(16)

    unpadded_length = String.length(unpadded)

    padded =
      case rem(unpadded_length, 2) do
        0 -> unpadded
        1 -> "0" <> unpadded
      end

    {:ok, data} = Data.cast("0x#{padded}")

    data
  end

  def internal_transaction_factory do
    type = internal_transaction_type()

    internal_transaction_factory(type)
  end

  def internal_transaction_create_factory do
    internal_transaction_factory(:create)
  end

  def internal_transaction_call_factory do
    internal_transaction_factory(:call)
  end

  # TODO add reward and suicide
  def internal_transaction_type do
    Enum.random(~w(call create)a)
  end

  def log_factory do
    %Log{
      address_hash: insert(:address).hash,
      data: data(:log_data),
      first_topic: nil,
      fourth_topic: nil,
      index: 0,
      second_topic: nil,
      third_topic: nil,
      transaction_hash: insert(:transaction).hash,
      type: sequence("0x")
    }
  end

  def public_key do
    data(:public_key)
  end

  def market_history_factory do
    %MarketHistory{
      closing_price: price(),
      opening_price: price(),
      date: Date.utc_today()
    }
  end

  def block_reward_factory do
    # Generate ranges like 1 - 10,000; 10,001 - 20,000, 20,001 - 30,000; etc
    x = sequence("block_range", & &1)
    lower = x * Kernel.+(10_000, 1)
    upper = Kernel.+(lower, 9_999)

    wei_per_ether = Decimal.new(1_000_000_000_000_000_000)

    reward_multiplier =
      1..5
      |> Enum.random()
      |> Decimal.new()

    reward = Decimal.mult(reward_multiplier, wei_per_ether)

    %Reward{
      block_range: %Range{from: lower, to: upper},
      reward: reward
    }
  end

  def transaction_factory do
    %Transaction{
      from_address_hash: insert(:address).hash,
      gas: Enum.random(21_000..100_000),
      gas_price: Enum.random(10..99) * 1_000_000_00,
      hash: transaction_hash(),
      input: transaction_input(),
      nonce: Enum.random(1..1_000),
      public_key: public_key(),
      r: sequence(:transaction_r, & &1),
      s: sequence(:transaction_s, & &1),
      standard_v: Enum.random(0..3),
      to_address_hash: insert(:address).hash,
      v: Enum.random(27..30),
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

  def transaction_input do
    data(:transaction_input)
  end

  defmacrop left + right do
    quote do
      fragment("? + ?", unquote(left), unquote(right))
    end
  end

  defmacrop coalesce(left, right) do
    quote do
      fragment("coalesce(?, ?)", unquote(left), unquote(right))
    end
  end

  defp block_hash_to_next_transaction_index(block_hash) do
    import Kernel, except: [+: 2]

    Repo.one!(
      from(
        transaction in Transaction,
        select: coalesce(max(transaction.index), -1) + 1,
        where: transaction.block_hash == ^block_hash
      )
    )
  end

  defp internal_transaction_factory(:call = type) do
    gas = Enum.random(21_000..100_000)
    gas_used = Enum.random(0..gas)

    transaction =
      :transaction
      |> insert()
      |> with_block()

    %InternalTransaction{
      from_address_hash: insert(:address).hash,
      to_address_hash: insert(:address).hash,
      call_type: :delegatecall,
      gas: gas,
      gas_used: gas_used,
      output: %Data{bytes: <<1>>},
      # caller MUST suppy `index`
      trace_address: [],
      transaction_hash: transaction.hash,
      type: type,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end

  defp internal_transaction_factory(:create = type) do
    gas = Enum.random(21_000..100_000)
    gas_used = Enum.random(0..gas)

    transaction =
      :transaction
      |> insert()
      |> with_block()

    %InternalTransaction{
      created_contract_code: data(:internal_transaction_created_contract_code),
      created_contract_address_hash: insert(:address).hash,
      from_address_hash: insert(:address).hash,
      gas: gas,
      gas_used: gas_used,
      # caller MUST suppy `index`
      init: data(:internal_transaction_init),
      trace_address: [],
      transaction_hash: transaction.hash,
      type: type,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end

  defp price do
    1..10_000
    |> Enum.random()
    |> Decimal.new()
    |> Decimal.div(Decimal.new(100))
  end
end
