defmodule Explorer.Staking.ContractState do
  @moduledoc """
  Fetches all information from POSDAO staking contracts.
  All contract calls are batched into requests, according to their dependencies.
  Subscribes to new block notifications and refreshes when previously unseen block arrives.
  """

  use GenServer

  require Decimal
  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Events.{Publisher, Subscriber}
  alias Explorer.SmartContract.Reader
  alias Explorer.Staking.{ContractReader, StakeSnapshotting}
  alias Explorer.Token.{BalanceReader, MetadataRetriever}

  @table_name __MODULE__
  @table_keys [
    :active_pools_length,
    :block_reward_contract,
    :epoch_end_block,
    :epoch_number,
    :epoch_start_block,
    :is_snapshotting,
    :last_change_block,
    :max_candidates,
    :min_candidate_stake,
    :min_delegator_stake,
    :pool_rewards,
    :seen_block,
    :snapshotted_epoch_number,
    :staking_allowed,
    :staking_contract,
    :token_contract,
    :token,
    :validator_min_reward_percent,
    :validator_set_apply_block,
    :validator_set_contract,
    :validators_length
  ]

  # token renewal frequency in blocks
  @token_renew_frequency 10

  defstruct [
    :eth_blocknumber_pull_interval,
    :eth_subscribe_max_delay,
    :snapshotting_finished,
    :timer,
    :contracts,
    :abi
  ]

  @spec get(atom(), value) :: value when value: any()
  def get(key, default \\ nil) when key in @table_keys do
    with info when info != :undefined <- :ets.info(@table_name),
         [{_, value}] <- :ets.lookup(@table_name, key) do
      value
    else
      _ -> default
    end
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    :ets.new(@table_name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    Subscriber.to(:last_block_number, :realtime)
    Subscriber.to(:stake_snapshotting_finished)

    staking_abi = abi("StakingAuRa")
    validator_set_abi = abi("ValidatorSetAuRa")
    block_reward_abi = abi("BlockRewardAuRa")
    token_abi = abi("Token")

    module_env = Application.get_env(:explorer, __MODULE__)

    # eth_blockNumber pull interval, in milliseconds
    eth_blocknumber_pull_interval = String.to_integer(module_env[:eth_blocknumber_pull_interval])

    # eth_subscribe max delay to switch to eth_blockNumber, in seconds
    eth_subscribe_max_delay = String.to_integer(module_env[:eth_subscribe_max_delay])

    staking_contract_address = module_env[:staking_contract_address]
    # 2d21d217 = keccak256(erc677TokenContract())
    erc_677_token_contract_signature = "2d21d217"

    # dfc8bf4e = keccak256(validatorSetContract())
    validator_set_contract_signature = "dfc8bf4e"

    %{
      "2d21d217" => {:ok, [token_contract_address]},
      "dfc8bf4e" => {:ok, [validator_set_contract_address]}
    } =
      Reader.query_contract(staking_contract_address, staking_abi, %{
        "#{erc_677_token_contract_signature}" => [],
        "#{validator_set_contract_signature}" => []
      })

    # 56b54bae = keccak256(blockRewardContract())
    block_reward_contract_signature = "56b54bae"

    %{"56b54bae" => {:ok, [block_reward_contract_address]}} =
      Reader.query_contract(validator_set_contract_address, validator_set_abi, %{
        "#{block_reward_contract_signature}" => []
      })

    state = %__MODULE__{
      eth_blocknumber_pull_interval: eth_blocknumber_pull_interval,
      eth_subscribe_max_delay: eth_subscribe_max_delay,
      snapshotting_finished: false,
      timer: nil,
      contracts: %{
        staking: staking_contract_address,
        validator_set: validator_set_contract_address,
        block_reward: block_reward_contract_address
      },
      abi: staking_abi ++ validator_set_abi ++ block_reward_abi
    }

    :ets.insert(@table_name,
      block_reward_contract: %{abi: block_reward_abi, address: block_reward_contract_address},
      is_snapshotting: false,
      last_change_block: 0,
      pool_rewards: %{},
      seen_block: 0,
      snapshotted_epoch_number: -1,
      staking_contract: %{abi: staking_abi, address: staking_contract_address},
      token_contract: %{abi: token_abi, address: token_contract_address},
      token: get_token(token_contract_address),
      validator_set_contract: %{abi: validator_set_abi, address: validator_set_contract_address}
    )

    {:ok, state, {:continue, []}}
  end

  def handle_continue(_, state) do
    # if eth_subscribe doesn't work during the first eth_subscribe_max_delay seconds
    # after server start, use eth_blockNumber
    timer = Process.send_after(self(), :eth_subscribe_stopped, state.eth_subscribe_max_delay * 1000)
    {:noreply, %{state | timer: timer}}
  end

  # handles an event about snapshotting finishing
  def handle_info({:chain_event, :stake_snapshotting_finished}, state) do
    {:noreply, %{state | snapshotting_finished: true}}
  end

  # received when eth_subscribe is stopped
  def handle_info(:eth_subscribe_stopped, state) do
    state =
      if Process.read_timer(state.timer) == false do
        {microseconds, state} =
          :timer.tc(
            fn st -> fetch_state(st, get_current_block_number()) end,
            [state]
          )

        # sleep up to eth_blocknumber_pull_interval milliseconds before the next eth_blockNumber request
        Process.send_after(
          self(),
          :eth_subscribe_stopped,
          max(state.eth_blocknumber_pull_interval - round(microseconds / 1000), 0)
        )

        state
      else
        state
      end

    {:noreply, state}
  end

  # catches a new block number from eth_subscribe
  def handle_info({:chain_event, :last_block_number, :realtime, block_number}, state) do
    if state.timer != nil do
      Process.cancel_timer(state.timer)
    end

    state = fetch_state(state, block_number)

    timer = Process.send_after(self(), :eth_subscribe_stopped, state.eth_subscribe_max_delay * 1000)
    {:noreply, %{state | timer: timer}}
  end

  # handles new block and decides to fetch fresh chain info
  defp fetch_state(state, block_number) do
    if block_number <= get(:seen_block) do
      state
    else
      fetch_state_internal(state, block_number)
    end
  end

  defp fetch_state_internal(state, block_number) do
    # read general info from the contracts (including pool list and validator list)
    global_responses =
      ContractReader.perform_requests(ContractReader.global_requests(block_number), state.contracts, state.abi)

    token_reward_to_distribute =
      ContractReader.call_current_token_reward_to_distribute(
        state.contracts.block_reward,
        state.contracts.staking,
        global_responses.epoch_number,
        block_number
      )

    current_pool_rewards =
      ContractReader.call_current_pool_rewards(
        state.contracts.block_reward,
        token_reward_to_distribute,
        global_responses.epoch_number,
        block_number
      )

    epoch_very_beginning = global_responses.epoch_start_block == block_number + 1

    start_snapshotting = start_snapshotting?(global_responses)

    # determine if something changed in contracts state since the previous seen block.
    # if something changed or the `fetch_state` function is called for the first time
    # or we are at the beginning of staking epoch or snapshotting recently finished
    # then we should update database
    last_change_block =
      max(global_responses.staking_last_change_block, global_responses.validator_set_last_change_block)

    first_fetch = get(:epoch_end_block, 0) == 0

    should_update_db =
      start_snapshotting or state.snapshotting_finished or first_fetch or last_change_block > get(:last_change_block)

    # save the general info to ETS (excluding pool list and validator list)
    set_settings(global_responses, state, block_number, last_change_block, current_pool_rewards)

    if epoch_very_beginning or start_snapshotting do
      # if the block_number is the latest block of the finished staking epoch
      # or we are starting Blockscout server, the BlockRewardAuRa contract balance
      # could increase before (without Mint/Transfer events),
      # so we need to update its balance in database
      update_block_reward_balance(block_number)
    end

    # we should update database as something changed in contracts state
    if should_update_db do
      update_database(
        epoch_very_beginning,
        start_snapshotting,
        global_responses,
        state.contracts,
        state.abi,
        block_number
      )
    end

    # notify the UI about a new block
    data = %{
      active_pools_length: get(:active_pools_length),
      block_number: block_number,
      epoch_end_block: global_responses.epoch_end_block,
      epoch_number: global_responses.epoch_number,
      max_candidates: global_responses.max_candidates,
      staking_allowed: global_responses.staking_allowed,
      staking_token_defined: get(:token, nil) != nil,
      validator_set_apply_block: global_responses.validator_set_apply_block
    }

    Publisher.broadcast([{:staking_update, data}], :realtime)

    if state.snapshotting_finished do
      %{state | snapshotting_finished: false}
    else
      state
    end
  end

  def calc_apy(reward_ratio, pool_reward, stake_amount, average_block_time, staking_epoch_duration) do
    if calc_apy_enabled?() and is_positive(reward_ratio) and pool_reward != nil and is_positive(stake_amount) and is_positive(average_block_time) and
         is_positive(staking_epoch_duration) do
      epochs_per_year = floor(31_536_000 / average_block_time / staking_epoch_duration)
      predicted_reward = decimal_to_float(reward_ratio) * pool_reward
      apy = predicted_reward / decimal_to_integer(stake_amount) * epochs_per_year
      %{apy: "#{floor(apy * 100) / 100}%", predicted_reward: floor(predicted_reward)}
    end
  end

  def calc_apy_enabled? do
    validator_set_apply_block = get(:validator_set_apply_block, 0)
    apy_start_block_number = validator_set_apply_block + get(:validators_length, 0) * 10
    get(:epoch_number, 0) > 0 and validator_set_apply_block > 0 and get(:seen_block, 0) >= apy_start_block_number
  end

  def staking_epoch_duration do
    epoch_start_block = get(:epoch_start_block)
    epoch_end_block = get(:epoch_end_block)

    if epoch_start_block == nil or epoch_end_block == nil do
      nil
    else
      if epoch_start_block == 0 do
        epoch_end_block
      else
        epoch_end_block - epoch_start_block + 1
      end
    end
  end

  defp is_positive(number) do
    if Decimal.is_decimal(number) do
      Decimal.positive?(number)
    else
      number > 0 and number != nil
    end
  end

  defp decimal_to_float(number) do
    if Decimal.is_decimal(number) do
      Decimal.to_float(number)
    else
      number
    end
  end

  defp decimal_to_integer(number) do
    if Decimal.is_decimal(number) do
      Decimal.to_integer(number)
    else
      number
    end
  end

  defp start_snapshotting?(global_responses) do
    global_responses.epoch_number > get(:snapshotted_epoch_number) && global_responses.epoch_number > 0 &&
      not get(:is_snapshotting)
  end

  defp update_database(epoch_very_beginning, start_snapshotting, global_responses, contracts, abi, block_number) do
    is_validator = Enum.into(global_responses.validators, %{}, &{address_bytes_to_string(&1), true})

    # form the list of validator pools
    validators =
      get_validators(
        start_snapshotting,
        global_responses,
        contracts,
        abi,
        block_number
      )

    # miningToStakingAddress mapping
    mining_to_staking_address = get_mining_to_staking_address(validators, contracts, abi, block_number)

    # the list of all pools (validators + active pools + inactive pools)
    pools =
      Enum.uniq(
        Map.values(mining_to_staking_address) ++
          global_responses.active_pools ++
          global_responses.inactive_pools
      )

    %{
      pool_staking_responses: pool_staking_responses,
      pool_mining_responses: pool_mining_responses,
      staker_responses: staker_responses
    } = get_responses(pools, block_number, contracts, abi)

    # to keep sort order when using `perform_grouped_requests` (see below)
    pool_staking_keys = Enum.map(pool_staking_responses, fn {pool_staking_address, _} -> pool_staking_address end)

    # call `BlockReward.validatorShare` function for each pool
    # to get validator's reward share of the pool (needed for the `Delegators` list in UI)
    candidate_reward_responses =
      get_candidate_reward_responses(
        pool_staking_responses,
        global_responses,
        pool_staking_keys,
        contracts,
        abi,
        block_number
      )

    # call `BlockReward.delegatorShare` function for each delegator
    # to get their reward share of the pool (needed for the `Delegators` list in UI)
    delegator_responses = get_delegator_responses(staker_responses)

    delegator_reward_responses =
      get_delegator_reward_responses(
        delegator_responses,
        pool_staking_responses,
        global_responses,
        contracts,
        abi,
        block_number
      )

    # calculate likelihood of becoming a validator on the next epoch
    [likelihood_values, total_likelihood] = global_responses.pools_likelihood
    # array of pool addresses (staking addresses)
    likelihood =
      global_responses.pools_to_be_elected
      |> Enum.zip(likelihood_values)
      |> Enum.into(%{})

    snapshotted_epoch_number = get(:snapshotted_epoch_number)

    # form entries for writing to the `staking_pools_delegators` table in DB
    delegator_entries = get_delegator_entries(staker_responses, delegator_reward_responses)

    # perform SQL queries
    {:ok, _} =
      Chain.import(%{
        staking_pools_delegators: %{params: delegator_entries},
        timeout: :infinity
      })

    # form entries for writing to the `staking_pools` table in DB.
    # !!! it's important to do this AFTER updating `staking_pools_delegators`
    # !!! table because the `get_pool_entries` function requires fresh
    # !!! info about delegators of validators from the `staking_pools_delegators` table
    pool_entries =
      get_pool_entries(%{
        pools: pools,
        pool_mining_responses: pool_mining_responses,
        pool_staking_responses: pool_staking_responses,
        is_validator: is_validator,
        candidate_reward_responses: candidate_reward_responses,
        global_responses: global_responses,
        snapshotted_epoch_number: snapshotted_epoch_number,
        likelihood: likelihood,
        total_likelihood: total_likelihood
      })

    # perform SQL queries
    {:ok, _} =
      Chain.import(%{
        staking_pools: %{params: pool_entries},
        timeout: :infinity
      })

    if start_snapshotting do
      do_start_snapshotting(
        epoch_very_beginning,
        pool_staking_responses,
        global_responses,
        contracts,
        abi,
        validators,
        mining_to_staking_address
      )
    end
  end

  defp get_current_block_number do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    result =
      %{id: 0, method: "eth_blockNumber", params: []}
      |> EthereumJSONRPC.request()
      |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)

    case result do
      {:ok, response} ->
        response
        |> String.replace_leading("0x", "")
        |> String.to_integer(16)

      _ ->
        0
    end
  end

  defp get_settings(global_responses, state, block_number) do
    validator_min_reward_percent =
      get_validator_min_reward_percent(global_responses.epoch_number, block_number, state.contracts, state.abi)

    base_settings = get_base_settings(global_responses, validator_min_reward_percent)

    update_token =
      get(:token) == nil or
        get(:token_contract).address != global_responses.token_contract_address or
        rem(block_number, @token_renew_frequency) == 0

    if update_token do
      Enum.concat(base_settings, token: get_token(global_responses.token_contract_address))
    else
      base_settings
    end
  end

  defp set_settings(global_responses, state, block_number, last_change_block, current_pool_rewards) do
    pool_rewards =
      global_responses.validators
      |> Enum.with_index()
      |> Map.new(fn {mining_address, index} ->
        {address_bytes_to_string(mining_address), Enum.at(current_pool_rewards, index)}
      end)

    settings =
      global_responses
      |> get_settings(state, block_number)
      |> Enum.concat(active_pools_length: Enum.count(global_responses.active_pools))
      |> Enum.concat(last_change_block: last_change_block)
      |> Enum.concat(pool_rewards: pool_rewards)
      |> Enum.concat(seen_block: block_number)
      |> Enum.concat(validators_length: Enum.count(global_responses.validators))

    :ets.insert(@table_name, settings)
  end

  defp get_mining_to_staking_address(validators, contracts, abi, block_number) do
    validators.all
    |> Enum.map(&ContractReader.staking_by_mining_request(&1, block_number))
    |> ContractReader.perform_grouped_requests(validators.all, contracts, abi)
    |> Map.new(fn {mining_address, resp} -> {mining_address, address_string_to_bytes(resp.staking_address).bytes} end)
  end

  defp get_responses(pools, block_number, contracts, abi) do
    # read pool info from the contracts by its staking address
    pool_staking_responses =
      pools
      |> Enum.map(&ContractReader.pool_staking_requests(&1, block_number))
      |> ContractReader.perform_grouped_requests(pools, contracts, abi)

    # read pool info from the contracts by its mining address
    pool_mining_responses =
      pools
      |> Enum.map(&ContractReader.pool_mining_requests(pool_staking_responses[&1].mining_address_hash, block_number))
      |> ContractReader.perform_grouped_requests(pools, contracts, abi)

    # get a flat list of all stakers in the form of {pool_staking_address, staker_address, is_active}
    stakers =
      Enum.flat_map(pool_staking_responses, fn {pool_staking_address, resp} ->
        [{pool_staking_address, pool_staking_address, true}] ++
          Enum.map(resp.active_delegators, &{pool_staking_address, &1, true}) ++
          Enum.map(resp.inactive_delegators, &{pool_staking_address, &1, false})
      end)

    # read info of each staker from the contracts
    staker_responses =
      stakers
      |> Enum.map(fn {pool_staking_address, staker_address, _is_active} ->
        ContractReader.staker_requests(pool_staking_address, staker_address, block_number)
      end)
      |> ContractReader.perform_grouped_requests(stakers, contracts, abi)

    %{
      pool_staking_responses: pool_staking_responses,
      pool_mining_responses: pool_mining_responses,
      staker_responses: staker_responses
    }
  end

  defp get_candidate_reward_responses(
         pool_staking_responses,
         global_responses,
         pool_staking_keys,
         contracts,
         abi,
         block_number
       ) do
    pool_staking_responses
    |> Enum.map(fn {_pool_staking_address, resp} ->
      ContractReader.validator_reward_request(
        [
          global_responses.epoch_number,
          resp.self_staked_amount,
          resp.total_staked_amount,
          1000_000
        ],
        block_number
      )
    end)
    |> ContractReader.perform_grouped_requests(pool_staking_keys, contracts, abi)
  end

  defp get_delegator_responses(staker_responses) do
    Enum.reduce(staker_responses, %{}, fn {{pool_staking_address, staker_address, _is_active} = key, value}, acc ->
      if pool_staking_address != staker_address do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp get_delegator_reward_responses(
         delegator_responses,
         pool_staking_responses,
         global_responses,
         contracts,
         abi,
         block_number
       ) do
    # to keep sort order when using `perform_grouped_requests` (see below)
    delegator_keys = Enum.map(delegator_responses, fn {key, _} -> key end)

    delegator_responses
    |> Enum.map(fn {{pool_staking_address, _staker_address, _is_active}, resp} ->
      staking_resp = pool_staking_responses[pool_staking_address]

      ContractReader.delegator_reward_request(
        [
          global_responses.epoch_number,
          resp.stake_amount,
          staking_resp.self_staked_amount,
          staking_resp.total_staked_amount,
          1000_000
        ],
        block_number
      )
    end)
    |> ContractReader.perform_grouped_requests(delegator_keys, contracts, abi)
  end

  defp get_delegator_entries(staker_responses, delegator_reward_responses) do
    Enum.map(staker_responses, fn {{pool_address, delegator_address, is_active} = key, response} ->
      delegator_share =
        if Map.has_key?(delegator_reward_responses, key) do
          delegator_reward_responses[key].delegator_share
        else
          0
        end

      Map.merge(response, %{
        address_hash: delegator_address,
        staking_address_hash: pool_address,
        is_active: is_active,
        reward_ratio: Float.floor(delegator_share / 10_000, 2)
      })
    end)
  end

  defp get_validator_min_reward_percent(epoch_number, block_number, contracts, abi) do
    ContractReader.perform_requests(
      ContractReader.validator_min_reward_percent_request(epoch_number, block_number),
      contracts,
      abi
    ).value
  end

  defp get_base_settings(global_responses, validator_min_reward_percent) do
    global_responses
    |> Map.take([
      :token_contract_address,
      :max_candidates,
      :min_candidate_stake,
      :min_delegator_stake,
      :epoch_number,
      :epoch_start_block,
      :epoch_end_block,
      :staking_allowed,
      :validator_set_apply_block
    ])
    |> Map.to_list()
    |> Enum.concat(validator_min_reward_percent: validator_min_reward_percent)
  end

  defp get_validators(
         start_snapshotting,
         global_responses,
         contracts,
         abi,
         block_number
       ) do
    if start_snapshotting do
      # eebc7a39 = keccak256(getPendingValidators())
      # 004a8803 = keccak256(validatorsToBeFinalized())
      if global_responses.validator_set_apply_block == 0 do
        %{
          "eebc7a39" => {:ok, [validators_pending]},
          "004a8803" => {:ok, [validators_to_be_finalized]}
        } =
          Reader.query_contract_by_block_number(
            contracts.validator_set,
            abi,
            %{
              "eebc7a39" => [],
              "004a8803" => []
            },
            block_number
          )

        validators_pending = Enum.uniq(validators_pending ++ validators_to_be_finalized)

        %{
          all: Enum.uniq(global_responses.validators ++ validators_pending),
          for_snapshot: validators_pending
        }
      else
        %{
          all: global_responses.validators,
          for_snapshot: global_responses.validators
        }
      end
    else
      %{all: global_responses.validators}
    end
  end

  def show_snapshotted_data(
        is_validator,
        validator_set_apply_block \\ nil,
        snapshotted_epoch_number \\ nil,
        epoch_number \\ nil
      ) do
    validator_set_apply_block =
      if validator_set_apply_block !== nil do
        validator_set_apply_block
      else
        get(:validator_set_apply_block)
      end

    snapshotted_epoch_number =
      if snapshotted_epoch_number !== nil do
        snapshotted_epoch_number
      else
        get(:snapshotted_epoch_number)
      end

    epoch_number =
      if epoch_number !== nil do
        epoch_number
      else
        get(:epoch_number)
      end

    is_validator && validator_set_apply_block > 0 && snapshotted_epoch_number === epoch_number
  end

  defp get_pool_entries(%{
         pools: pools,
         pool_mining_responses: pool_mining_responses,
         pool_staking_responses: pool_staking_responses,
         is_validator: is_validator,
         candidate_reward_responses: candidate_reward_responses,
         global_responses: global_responses,
         snapshotted_epoch_number: snapshotted_epoch_number,
         likelihood: likelihood,
         total_likelihood: total_likelihood
       }) do
    # total amount staked into all active pools
    staked_total = Enum.sum(for {_, pool} <- pool_staking_responses, pool.is_active, do: pool.total_staked_amount)

    Enum.map(pools, fn pool_staking_address ->
      staking_resp = pool_staking_responses[pool_staking_address]
      mining_resp = pool_mining_responses[pool_staking_address]
      candidate_reward_resp = candidate_reward_responses[pool_staking_address]
      is_validator = is_validator[staking_resp.mining_address_hash] || false

      delegators_count =
        length(staking_resp.active_delegators) +
          if show_snapshotted_data(
               is_validator,
               global_responses.validator_set_apply_block,
               snapshotted_epoch_number,
               global_responses.epoch_number
             ) do
            Chain.staking_pool_snapshotted_inactive_delegators_count(pool_staking_address)
          else
            0
          end

      is_unremovable = address_bytes_to_string(pool_staking_address) == global_responses.unremovable_validator

      likelihood_value =
        if get(:active_pools_length) > global_responses.max_validators and not is_unremovable do
          ratio(likelihood[pool_staking_address] || 0, total_likelihood)
        else
          100
        end

      %{
        staking_address_hash: pool_staking_address,
        delegators_count: delegators_count,
        stakes_ratio:
          if staking_resp.is_active do
            ratio(staking_resp.total_staked_amount, staked_total)
          else
            0
          end,
        validator_reward_ratio: Float.floor(candidate_reward_resp.validator_share / 10_000, 2),
        likelihood: likelihood_value,
        validator_reward_percent: staking_resp.validator_reward_percent / 10_000,
        is_deleted: false,
        is_validator: is_validator,
        is_unremovable: is_unremovable,
        ban_reason: binary_to_string(mining_resp.ban_reason)
      }
      |> Map.merge(
        Map.take(staking_resp, [
          :is_active,
          :mining_address_hash,
          :self_staked_amount,
          :total_staked_amount
        ])
      )
      |> Map.merge(
        Map.take(mining_resp, [
          :are_delegators_banned,
          :banned_delegators_until,
          :banned_until,
          :is_banned,
          :was_banned_count,
          :was_validator_count
        ])
      )
    end)
  end

  defp update_block_reward_balance(block_number) do
    # update ERC balance of the BlockReward contract
    token = get(:token)

    if token != nil do
      block_reward_address = address_string_to_bytes(get(:block_reward_contract).address)
      token_contract_address_hash = token.contract_address_hash

      block_reward_balance =
        BalanceReader.get_balances_of([
          %{
            token_contract_address_hash: token_contract_address_hash,
            address_hash: block_reward_address.bytes,
            block_number: block_number
          }
        ])[:ok]

      token_params =
        token_contract_address_hash
        |> MetadataRetriever.get_functions_of()
        |> Map.merge(%{
          contract_address_hash: token_contract_address_hash,
          type: "ERC-20"
        })

      import_result =
        Chain.import(%{
          addresses: %{params: [%{hash: block_reward_address.bytes}], on_conflict: :nothing},
          address_current_token_balances: %{
            params: [
              %{
                address_hash: block_reward_address.bytes,
                token_contract_address_hash: token_contract_address_hash,
                block_number: block_number,
                value: block_reward_balance,
                value_fetched_at: DateTime.utc_now()
              }
            ]
          },
          tokens: %{params: [token_params]}
        })

      with {:ok, _} <- import_result,
           do:
             Publisher.broadcast(
               [
                 {
                   :address_token_balances,
                   [
                     %{address_hash: block_reward_address.struct, block_number: block_number}
                   ]
                 }
               ],
               :on_demand
             )
    end
  end

  defp do_start_snapshotting(
         epoch_very_beginning,
         pool_staking_responses,
         global_responses,
         contracts,
         abi,
         validators,
         mining_to_staking_address
       ) do
    # start snapshotting at the beginning of the staking epoch
    :ets.insert(@table_name, is_snapshotting: true)

    cached_pool_staking_responses =
      if epoch_very_beginning do
        pool_staking_responses
      else
        %{}
      end

    spawn(StakeSnapshotting, :do_snapshotting, [
      %{contracts: contracts, abi: abi, ets_table_name: @table_name},
      global_responses.epoch_number,
      cached_pool_staking_responses,
      # mining addresses of pending/current validators
      validators.for_snapshot,
      mining_to_staking_address,
      # the last block of the previous staking epoch
      global_responses.epoch_start_block - 1
    ])
  end

  defp get_token(address) do
    if address == "0x0000000000000000000000000000000000000000" do
      # the token address is empty, so return nil
      nil
    else
      case Chain.string_to_address_hash(address) do
        {:ok, address_hash} ->
          # the token address has correct format, so try to read the token
          # from DB or from its contract
          case Chain.token_from_address_hash(address_hash) do
            {:ok, token} ->
              # the token is read from DB
              token

            _ ->
              fetch_token(address, address_hash)
          end

        _ ->
          # the token address has incorrect format
          nil
      end
    end
  end

  defp fetch_token(address, address_hash) do
    # the token doesn't exist in DB, so try
    # to read it from a contract and then write to DB.
    # Since the Staking DApp doesn't use the token fields
    # which dinamically change (such as totalSupply),
    # we don't pass the current block_number to the RPC request
    token_functions = MetadataRetriever.get_functions_of(address)

    if map_size(token_functions) > 0 do
      # the token is successfully read from its contract
      token_params =
        Map.merge(token_functions, %{
          contract_address_hash: address,
          type: "ERC-20"
        })

      # try to write the token info to DB
      import_result =
        Chain.import(%{
          addresses: %{params: [%{hash: address}], on_conflict: :nothing},
          tokens: %{params: [token_params]}
        })

      case import_result do
        {:ok, _} ->
          # the token is successfully added to DB, so return it as a result
          case Chain.token_from_address_hash(address_hash) do
            {:ok, token} -> token
            _ -> nil
          end

        _ ->
          # cannot write the token info to DB
          nil
      end
    else
      # cannot read the token info from its contract
      nil
    end
  end

  defp ratio(_numerator, 0), do: 0
  defp ratio(numerator, denominator), do: numerator / denominator * 100

  defp address_bytes_to_string(hash), do: "0x" <> Base.encode16(hash, case: :lower)

  defp address_string_to_bytes(address_string) do
    {
      :ok,
      %Chain.Hash{
        byte_count: _,
        bytes: bytes
      } = struct
    } = Chain.string_to_address_hash(address_string)

    %{bytes: bytes, struct: struct}
  end

  # sobelow_skip ["Traversal"]
  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/posdao/#{file_name}.json")
    |> File.read!()
    |> Jason.decode!()
  end

  defp binary_to_string(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.filter(fn x -> x != 0 end)
    |> List.to_string()
  end
end
