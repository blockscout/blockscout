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
    SmartContract,
    Token,
    TokenTransfer,
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

  def contract_address_factory do
    %Address{
      hash: address_hash(),
      contract_code: Map.fetch!(contract_code_info(), :bytecode)
    }
  end

  def contract_code_info do
    %{
      bytecode:
        "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a72305820f65a3adc1cfb055013d1dc37d0fe98676e2a5963677fa7541a10386d163446680029",
      name: "SimpleStorage",
      source_code: """
      pragma solidity ^0.4.24;

      contract SimpleStorage {
          uint storedData;

          function set(uint x) public {
              storedData = x;
          }

          function get() public constant returns (uint) {
              return storedData;
          }
      }
      """,
      version: "v0.4.24+commit.e67f0147",
      optimized: false
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
      miner: build(:address),
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

  def internal_transaction_factory() do
    gas = Enum.random(21_000..100_000)
    gas_used = Enum.random(0..gas)

    %InternalTransaction{
      from_address: build(:address),
      to_address: build(:address),
      call_type: :delegatecall,
      gas: gas,
      gas_used: gas_used,
      output: %Data{bytes: <<1>>},
      # caller MUST suppy `index`
      trace_address: [],
      # caller MUST supply `transaction` because it can't be built lazily to allow overrides without creating an extra
      # transaction
      type: :call,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end

  def internal_transaction_create_factory() do
    gas = Enum.random(21_000..100_000)
    gas_used = Enum.random(0..gas)

    %InternalTransaction{
      created_contract_code: data(:internal_transaction_created_contract_code),
      created_contract_address: build(:address),
      from_address: build(:address),
      gas: gas,
      gas_used: gas_used,
      # caller MUST suppy `index`
      init: data(:internal_transaction_init),
      trace_address: [],
      # caller MUST supply `transaction` because it can't be built lazily to allow overrides without creating an extra
      # transaction
      type: :create,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end

  def log_factory do
    %Log{
      address: build(:address),
      data: data(:log_data),
      first_topic: nil,
      fourth_topic: nil,
      index: 0,
      second_topic: nil,
      third_topic: nil,
      transaction: build(:transaction),
      type: sequence("0x")
    }
  end

  def token_factory do
    %Token{
      name: "Infinite Token",
      symbol: "IT",
      total_supply: 1_000_000_000,
      decimals: 18,
      owner_address: build(:address),
      contract_address: build(:address)
    }
  end

  def token_transfer_log_factory do
    token_contract_address = build(:address)
    to_address = build(:address)
    from_address = build(:address)

    transaction = build(:transaction, to_address: token_contract_address, from_address: from_address)

    log_params = %{
      first_topic: TokenTransfer.constant(),
      second_topic: zero_padded_address_hash_string(from_address.hash),
      third_topic: zero_padded_address_hash_string(to_address.hash),
      data: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
      transaction: transaction
    }

    build(:log, log_params)
  end

  def token_transfer_log_with_transaction(%Log{} = log, %Transaction{} = transaction) do
    params = %{
      second_topic: zero_padded_address_hash_string(transaction.from_address.hash),
      transaction: transaction
    }

    struct!(log, params)
  end

  def token_transfer_log_with_to_address(%Log{} = log, %Address{} = to_address) do
    %Log{log | third_topic: zero_padded_address_hash_string(to_address.hash)}
  end

  def token_transfer_factory do
    log = insert(:token_transfer_log)
    to_address_hash = address_hash_from_zero_padded_hash_string(log.third_topic)

    # `to_address` is only the only thing that isn't created from the token_transfer_log_factory

    insert(:address, hash: to_address_hash)

    from_address_hash = address_hash_from_zero_padded_hash_string(log.second_topic)

    %TokenTransfer{
      amount: Decimal.new(1),
      from_address: nil,
      from_address_hash: from_address_hash,
      to_address: nil,
      to_address_hash: to_address_hash,
      transaction: nil,
      transaction_hash: log.transaction.hash,
      token: build(:token, contract_address_hash: log.transaction.to_address.hash, contract_address: nil),
      log: log
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
      from_address: build(:address),
      gas: Enum.random(21_000..100_000),
      gas_price: Enum.random(10..99) * 1_000_000_00,
      hash: transaction_hash(),
      input: transaction_input(),
      nonce: Enum.random(1..1_000),
      public_key: public_key(),
      r: sequence(:transaction_r, & &1),
      s: sequence(:transaction_s, & &1),
      standard_v: Enum.random(0..3),
      to_address: build(:address),
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

  def smart_contract_factory() do
    %SmartContract{
      address_hash: insert(:address).hash,
      compiler_version: "0.4.24",
      name: "SimpleStorage",
      contract_source_code:
        "pragma solidity ^0.4.24; contract SimpleStorage {uint storedData; function set(uint x) public {storedData = x; } function get() public constant returns (uint) {return storedData; } }",
      optimization: false,
      abi: [
        %{
          "constant" => false,
          "inputs" => [%{"name" => "x", "type" => "uint256"}],
          "name" => "set",
          "outputs" => [],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        },
        %{
          "constant" => true,
          "inputs" => [],
          "name" => "get",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        }
      ]
    }
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

  defp price do
    1..10_000
    |> Enum.random()
    |> Decimal.new()
    |> Decimal.div(Decimal.new(100))
  end

  defp zero_padded_address_hash_string(%Explorer.Chain.Hash{byte_count: 20} = hash) do
    "0x" <> hash_string = Explorer.Chain.Hash.to_string(hash)
    "0x000000000000000000000000" <> hash_string
  end

  defp address_hash_from_zero_padded_hash_string("0x000000000000000000000000" <> hash_string) do
    {:ok, hash} = Explorer.Chain.Hash.cast(Explorer.Chain.Hash.Truncated, "0x" <> hash_string)
    hash
  end
end
