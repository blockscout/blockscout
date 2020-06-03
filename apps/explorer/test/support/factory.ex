defmodule Explorer.Factory do
  use ExMachina.Ecto, repo: Explorer.Repo

  require Ecto.Query

  import Ecto.Query
  import Kernel, except: [+: 2]

  alias Comeonin.Bcrypt
  alias Explorer.Accounts.{User, UserContact}
  alias Explorer.Admin.Administrator
  alias Explorer.Chain.Block.{EmissionReward, Range, Reward}

  alias Explorer.Chain.{
    Address,
    Address.CurrentTokenBalance,
    Address.TokenBalance,
    Address.CoinBalance,
    Block,
    ContractMethod,
    Data,
    DecompiledSmartContract,
    Hash,
    InternalTransaction,
    Log,
    PendingBlockOperation,
    SmartContract,
    Token,
    TokenTransfer,
    Token.Instance,
    Transaction,
    StakingPool,
    StakingPoolsDelegator
  }

  alias Explorer.Market.MarketHistory
  alias Explorer.Repo

  def address_factory do
    %Address{
      hash: address_hash()
    }
  end

  def address_name_factory do
    %Address.Name{
      address: build(:address),
      name: "FooContract"
    }
  end

  def unfetched_balance_factory do
    %CoinBalance{
      address_hash: address_hash(),
      block_number: block_number()
    }
  end

  def update_balance_value(%CoinBalance{address_hash: address_hash, block_number: block_number}, value) do
    Repo.update_all(
      from(
        balance in CoinBalance,
        where: balance.address_hash == ^address_hash and balance.block_number == ^block_number
      ),
      set: [value: value, value_fetched_at: DateTime.utc_now()]
    )
  end

  def fetched_balance_factory do
    unfetched_balance_factory()
    |> struct!(value: Enum.random(1..100_000))
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
      tx_input:
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a72305820853a985d0a4b20246785fc2f0357c202faa3db289980a48737180f358f9ddc3c0029",
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
      ],
      version: "v0.4.24+commit.e67f0147",
      optimized: false
    }
  end

  def address_hash do
    {:ok, address_hash} =
      "address_hash"
      |> sequence(& &1)
      |> Hash.Address.cast()

    if to_string(address_hash) == "0x0000000000000000000000000000000000000000" do
      address_hash()
    else
      address_hash
    end
  end

  def block_factory do
    %Block{
      consensus: true,
      number: block_number(),
      hash: block_hash(),
      parent_hash: block_hash(),
      nonce: sequence("block_nonce", & &1),
      miner: build(:address),
      difficulty: Enum.random(1..100_000),
      total_difficulty: Enum.random(1..100_000),
      size: Enum.random(1..100_000),
      gas_limit: Enum.random(1..100_000),
      gas_used: Enum.random(1..100_000),
      timestamp: DateTime.utc_now(),
      refetch_needed: false
    }
  end

  def contract_method_factory() do
    %ContractMethod{
      identifier: Base.decode16!("60fe47b1", case: :lower),
      abi: %{
        "constant" => false,
        "inputs" => [%{"name" => "x", "type" => "uint256"}],
        "name" => "set",
        "outputs" => [],
        "payable" => false,
        "stateMutability" => "nonpayable",
        "type" => "function"
      },
      type: "function"
    }
  end

  def block_hash do
    {:ok, block_hash} =
      "block_hash"
      |> sequence(& &1)
      |> Hash.Full.cast()

    block_hash
  end

  def block_number do
    sequence("block_number", & &1)
  end

  def block_second_degree_relation_factory do
    %Block.SecondDegreeRelation{
      uncle_hash: block_hash(),
      nephew: build(:block),
      index: 0
    }
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

  # The `transaction.block` must be consensus.  Non-consensus blocks can only be associated with the
  # `transaction_forks`.
  def with_block(transactions, %Block{consensus: true} = block) when is_list(transactions) do
    Enum.map(transactions, &with_block(&1, block))
  end

  def with_block(%Transaction{index: nil} = transaction, collated_params) when is_list(collated_params) do
    block = insert(:block)
    with_block(transaction, block, collated_params)
  end

  def with_block(
        %Transaction{index: nil} = transaction,
        # The `transaction.block` must be consensus.  Non-consensus blocks can only be associated with the
        # `transaction_forks`.
        %Block{consensus: true, hash: block_hash, number: block_number},
        collated_params
      )
      when is_list(collated_params) do
    next_transaction_index = block_hash_to_next_transaction_index(block_hash)

    cumulative_gas_used = collated_params[:cumulative_gas_used] || Enum.random(21_000..100_000)
    gas_used = collated_params[:gas_used] || Enum.random(21_000..100_000)
    status = Keyword.get(collated_params, :status, Enum.random([:ok, :error]))

    error = (status == :error && collated_params[:error]) || nil

    transaction
    |> Transaction.changeset(%{
      block_hash: block_hash,
      block_number: block_number,
      cumulative_gas_used: cumulative_gas_used,
      from_address_hash: transaction.from_address_hash,
      to_address_hash: transaction.to_address_hash,
      error: error,
      gas_used: gas_used,
      index: next_transaction_index,
      status: status
    })
    |> Repo.update!()
    |> Repo.preload(:block)
  end

  def with_contract_creation(%Transaction{} = transaction, %Address{hash: contract_address_hash}) do
    transaction
    |> Transaction.changeset(%{
      created_contract_address_hash: contract_address_hash
    })
    |> Repo.update!()
  end

  def with_contract_creation(%InternalTransaction{} = internal_transaction, %Address{
        contract_code: contract_code,
        hash: contract_address_hash
      }) do
    internal_transaction
    |> InternalTransaction.changeset(%{
      contract_code: contract_code,
      created_contract_address_hash: contract_address_hash
    })
    |> Repo.update!()
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

  def pending_block_operation_factory do
    %PendingBlockOperation{
      # caller MUST supply block
      # all operations will default to false
      fetch_internal_transactions: false
    }
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
      input: %Data{bytes: <<1>>},
      output: %Data{bytes: <<2>>},
      # caller MUST supply `index`
      trace_address: [],
      # caller MUST supply `transaction` because it can't be built lazily to allow overrides without creating an extra
      # transaction
      # caller MUST supply `block_hash` (usually the same as the transaction's)
      # caller MUST supply `block_index`
      type: :call,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end

  def internal_transaction_create_factory() do
    gas = Enum.random(21_000..100_000)
    gas_used = Enum.random(0..gas)

    contract_code = Map.fetch!(contract_code_info(), :bytecode)

    %InternalTransaction{
      created_contract_code: contract_code,
      created_contract_address: build(:address, contract_code: contract_code),
      from_address: build(:address),
      gas: gas,
      gas_used: gas_used,
      # caller MUST supply `index`
      init: data(:internal_transaction_init),
      trace_address: [],
      # caller MUST supply `transaction` because it can't be built lazily to allow overrides without creating an extra
      # transaction
      # caller MUST supply `block_hash` (usually the same as the transaction's)
      # caller MUST supply `block_index`
      type: :create,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end

  def internal_transaction_selfdestruct_factory() do
    %InternalTransaction{
      from_address: build(:address),
      trace_address: [],
      # caller MUST supply `transaction` because it can't be built lazily to allow overrides without creating an extra
      # transaction
      type: :selfdestruct,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end

  def log_factory do
    block = build(:block)

    %Log{
      address: build(:address),
      block: block,
      block_number: block.number,
      data: data(:log_data),
      first_topic: nil,
      fourth_topic: nil,
      index: sequence("log_index", & &1),
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
      contract_address: build(:address),
      type: "ERC-20",
      cataloged: true
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
      address_hash: token_contract_address.hash,
      address: nil,
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
    log = build(:token_transfer_log)
    to_address_hash = address_hash_from_zero_padded_hash_string(log.third_topic)
    from_address_hash = address_hash_from_zero_padded_hash_string(log.second_topic)

    # `to_address` is only the only thing that isn't created from the token_transfer_log_factory
    to_address = build(:address, hash: to_address_hash)
    from_address = build(:address, hash: from_address_hash)
    contract_code = Map.fetch!(contract_code_info(), :bytecode)

    token_address = insert(:contract_address, contract_code: contract_code)
    insert(:token, contract_address: token_address)

    %TokenTransfer{
      block: build(:block),
      amount: Decimal.new(1),
      block_number: block_number(),
      from_address: from_address,
      to_address: to_address,
      token_contract_address: token_address,
      transaction: log.transaction,
      log_index: log.index
    }
  end

  def market_history_factory do
    %MarketHistory{
      closing_price: price(),
      opening_price: price(),
      date: Date.utc_today()
    }
  end

  def emission_reward_factory do
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

    %EmissionReward{
      block_range: %Range{from: lower, to: upper},
      reward: reward
    }
  end

  def reward_factory do
    %Reward{
      address_hash: build(:address).hash,
      address_type: :validator,
      block_hash: build(:block).hash,
      reward: Decimal.new(3)
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
      r: sequence(:transaction_r, & &1),
      s: sequence(:transaction_s, & &1),
      to_address: build(:address),
      v: Enum.random(27..30),
      value: Enum.random(1..100_000)
    }
  end

  def transaction_to_verified_contract_factory do
    smart_contract = build(:smart_contract)

    address = %Address{
      hash: address_hash(),
      verified: true,
      contract_code: contract_code_info().bytecode,
      smart_contract: smart_contract
    }

    input_data =
      "set(uint)"
      |> ABI.encode([50])
      |> Base.encode16(case: :lower)

    build(:transaction, to_address: address, input: "0x" <> input_data)
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

  def transaction_fork_factory do
    %Transaction.Fork{
      hash: transaction_hash(),
      index: 0,
      uncle_hash: block_hash()
    }
  end

  def smart_contract_factory do
    contract_code_info = contract_code_info()

    %SmartContract{
      address_hash: insert(:address, contract_code: contract_code_info.bytecode, verified: true).hash,
      compiler_version: contract_code_info.version,
      name: contract_code_info.name,
      contract_source_code: contract_code_info.source_code,
      optimization: contract_code_info.optimized,
      abi: contract_code_info.abi
    }
  end

  def decompiled_smart_contract_factory do
    contract_code_info = contract_code_info()

    %DecompiledSmartContract{
      address_hash: insert(:address, contract_code: contract_code_info.bytecode, decompiled: true).hash,
      decompiler_version: "test_decompiler",
      decompiled_source_code: contract_code_info.source_code
    }
  end

  def token_instance_factory do
    %Instance{
      token_contract_address_hash: build(:address),
      token_id: 5,
      metadata: %{key: "value"},
      error: nil
    }
  end

  def token_balance_factory do
    %TokenBalance{
      address: build(:address),
      token_contract_address_hash: insert(:token).contract_address_hash,
      block_number: block_number(),
      value: Enum.random(1..100_000),
      value_fetched_at: DateTime.utc_now()
    }
  end

  def address_current_token_balance_factory do
    %CurrentTokenBalance{
      address: build(:address),
      token_contract_address_hash: insert(:token).contract_address_hash,
      block_number: block_number(),
      value: Enum.random(1..100_000),
      value_fetched_at: DateTime.utc_now()
    }
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
    {:ok, hash} = Explorer.Chain.Hash.cast(Explorer.Chain.Hash.Address, "0x" <> hash_string)
    hash
  end

  def user_factory do
    username = sequence("user", &"user#{&1}")

    %User{
      username: username,
      password_hash: Bcrypt.hashpwsalt("password"),
      contacts: [
        %UserContact{
          email: "#{username}@blockscout",
          primary: true,
          verified: true
        }
      ]
    }
  end

  def administrator_factory do
    %Administrator{
      role: "owner",
      user: build(:user)
    }
  end

  def staking_pool_factory do
    wei_per_ether = 1_000_000_000_000_000_000

    %StakingPool{
      staking_address_hash: address_hash(),
      mining_address_hash: address_hash(),
      banned_until: 0,
      delegators_count: 0,
      is_active: true,
      is_banned: false,
      is_validator: true,
      staked_amount: wei_per_ether * 500,
      self_staked_amount: wei_per_ether * 300,
      was_banned_count: 0,
      was_validator_count: 1
    }
  end

  def staking_pools_delegator_factory do
    wei_per_ether = 1_000_000_000_000_000_000

    %StakingPoolsDelegator{
      pool_address_hash: address_hash(),
      delegator_address_hash: address_hash(),
      max_ordered_withdraw_allowed: wei_per_ether * 100,
      max_withdraw_allowed: wei_per_ether * 50,
      ordered_withdraw: wei_per_ether * 600,
      stake_amount: wei_per_ether * 200,
      ordered_withdraw_epoch: 2
    }
  end
end
