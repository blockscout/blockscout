defmodule BlockScoutWeb.StakesChannel do
  @moduledoc """
  Establishes pub/sub channel for staking page live updates.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.{StakesController, StakesView}
  alias Explorer.Chain
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Token
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Staking.{ContractReader, ContractState}
  alias Phoenix.View

  import BlockScoutWeb.Gettext

  @searching_claim_reward_pools :searching_claim_reward_pools

  intercept(["staking_update"])

  def join("stakes:staking_update", _params, socket) do
    {:ok, %{}, socket}
  end

  def terminate(_, socket) do
    s = socket.assigns[@searching_claim_reward_pools]
    if s != nil do
      :ets.delete(ContractState, searching_claim_reward_pools_key(s.staker))
    end
  end

  def handle_in("set_account", account, socket) do
    socket =
      socket
      |> assign(:account, account)
      |> push_staking_contract()

    handle_out(
      "staking_update",
      %{
        block_number: BlockNumber.get_max(),
        epoch_number: ContractState.get(:epoch_number, 0),
        staking_allowed: ContractState.get(:staking_allowed, false),
        staking_token_defined: ContractState.get(:token, nil) != nil,
        validator_set_apply_block: ContractState.get(:validator_set_apply_block, 0)
      },
      socket
    )
  end

  def handle_in("render_validator_info", %{"address" => staking_address}, socket) do
    pool = Chain.staking_pool(staking_address)
    delegator = socket.assigns[:account] && Chain.staking_pool_delegator(staking_address, socket.assigns.account)
    average_block_time = AverageBlockTime.average_block_time()
    token = ContractState.get(:token)

    html =
      View.render_to_string(StakesView, "_stakes_modal_pool_info.html",
        validator: pool,
        delegator: delegator,
        average_block_time: average_block_time,
        token: token
      )

    {:reply, {:ok, %{html: html}}, socket}
  end

  def handle_in("render_delegators_list", %{"address" => pool_staking_address}, socket) do
    pool = Chain.staking_pool(pool_staking_address)
    token = ContractState.get(:token)
    validator_min_reward_percent = ContractState.get(:validator_min_reward_percent)
    show_snapshotted_data = ContractState.show_snapshotted_data(pool.is_validator)

    stakers =
      pool_staking_address
      |> Chain.staking_pool_delegators(show_snapshotted_data)
      |> Enum.sort_by(fn staker ->
        staker_address = to_string(staker.address_hash)

        cond do
          staker_address == pool_staking_address -> 0
          staker_address == socket.assigns[:account] -> 1
          true -> 2
        end
      end)

    html =
      View.render_to_string(StakesView, "_stakes_modal_delegators_list.html",
        account: socket.assigns[:account],
        pool: pool,
        conn: socket,
        stakers: stakers,
        token: token,
        show_snapshotted_data: show_snapshotted_data,
        validator_min_reward_percent: validator_min_reward_percent
      )

    {:reply, {:ok, %{html: html}}, socket}
  end

  def handle_in("render_become_candidate", _, socket) do
    min_candidate_stake = ContractState.get(:min_candidate_stake)
    token = ContractState.get(:token)
    balance = Chain.fetch_last_token_balance(socket.assigns.account, token.contract_address_hash)

    html =
      View.render_to_string(StakesView, "_stakes_modal_become_candidate.html",
        min_candidate_stake: min_candidate_stake,
        balance: balance,
        token: token
      )

    result = %{
      html: html,
      balance: balance,
      min_candidate_stake: min_candidate_stake
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_in("render_make_stake", %{"address" => staking_address}, socket) do
    pool = Chain.staking_pool(staking_address)
    delegator = Chain.staking_pool_delegator(staking_address, socket.assigns.account)
    token = ContractState.get(:token)
    balance = Chain.fetch_last_token_balance(socket.assigns.account, token.contract_address_hash)

    min_stake =
      if staking_address == socket.assigns.account do
        ContractState.get(:min_candidate_stake)
      else
        ContractState.get(:min_delegator_stake)
      end

    html =
      View.render_to_string(StakesView, "_stakes_modal_stake.html",
        min_stake: min_stake,
        balance: balance,
        token: token,
        pool: pool,
        delegator: delegator
      )

    result = %{
      html: html,
      balance: balance,
      delegator_staked: (delegator && delegator.stake_amount) || 0,
      min_stake: min_stake,
      self_staked_amount: pool.self_staked_amount,
      total_staked_amount: pool.total_staked_amount
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_in("render_move_stake", %{"from" => from_address, "to" => to_address, "amount" => amount}, socket) do
    pool_from = Chain.staking_pool(from_address)
    pool_to = to_address && Chain.staking_pool(to_address)
    pools = Chain.staking_pools(:active, :all)
    delegator_from = Chain.staking_pool_delegator(from_address, socket.assigns.account)
    delegator_to = to_address && Chain.staking_pool_delegator(to_address, socket.assigns.account)
    token = ContractState.get(:token)

    min_from_stake =
      if delegator_from.address_hash == delegator_from.staking_address_hash do
        ContractState.get(:min_candidate_stake)
      else
        ContractState.get(:min_delegator_stake)
      end

    min_to_stake =
      if to_address == socket.assigns.account do
        ContractState.get(:min_candidate_stake)
      else
        ContractState.get(:min_delegator_stake)
      end

    html =
      View.render_to_string(StakesView, "_stakes_modal_move.html",
        token: token,
        pools: pools,
        pool_from: pool_from,
        pool_to: pool_to,
        delegator_from: delegator_from,
        delegator_to: delegator_to,
        amount: amount
      )

    result = %{
      html: html,
      max_withdraw_allowed: delegator_from.max_withdraw_allowed,
      from: %{
        stake_amount: delegator_from.stake_amount,
        min_stake: min_from_stake,
        self_staked_amount: pool_from.self_staked_amount,
        total_staked_amount: pool_from.total_staked_amount
      },
      to:
        if pool_to do
          %{
            stake_amount: (delegator_to && delegator_to.stake_amount) || 0,
            min_stake: min_to_stake,
            self_staked_amount: pool_to.self_staked_amount,
            total_staked_amount: pool_to.total_staked_amount
          }
        end
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_in("render_withdraw_stake", %{"address" => staking_address}, socket) do
    pool = Chain.staking_pool(staking_address)
    token = ContractState.get(:token)
    delegator = Chain.staking_pool_delegator(staking_address, socket.assigns.account)

    min_stake =
      if delegator.address_hash == delegator.staking_address_hash do
        ContractState.get(:min_candidate_stake)
      else
        ContractState.get(:min_delegator_stake)
      end

    html =
      View.render_to_string(StakesView, "_stakes_modal_withdraw.html",
        token: token,
        delegator: delegator,
        pool: pool
      )

    result = %{
      html: html,
      self_staked_amount: pool.self_staked_amount,
      total_staked_amount: pool.total_staked_amount,
      delegator_staked: delegator.stake_amount,
      ordered_withdraw: delegator.ordered_withdraw,
      max_withdraw_allowed: delegator.max_withdraw_allowed,
      max_ordered_withdraw_allowed: delegator.max_ordered_withdraw_allowed,
      min_stake: min_stake
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_in("render_claim_reward", data, socket) do
    staker = socket.assigns[:account]

    search_in_progress = if socket.assigns[@searching_claim_reward_pools] do
      true
    else
      with [{_, true}] <- :ets.lookup(ContractState, searching_claim_reward_pools_key(staker)) do
        true
      end
    end

    staking_contract_address = try do ContractState.get(:staking_contract).address after end
    
    cond do
      search_in_progress == true ->
        {:reply, {:error, %{reason: gettext("Pools searching is already in progress for this address")}}, socket}
      staker == nil || staker == "" || staker == "0x0000000000000000000000000000000000000000" ->
        {:reply, {:error, %{reason: gettext("Unknown staker address. Please, choose your account in MetaMask")}}, socket}
      staking_contract_address == nil || staking_contract_address == "" || staking_contract_address == "0x0000000000000000000000000000000000000000" ->
        {:reply, {:error, %{reason: gettext("Unknown address of Staking contract. Please, contact support")}}, socket}
      true ->
        result = if data["preload"] do
          %{
            html: View.render_to_string(StakesView, "_stakes_modal_claim_reward.html", %{}),
            socket: socket
          }
        else
          task = Task.async(__MODULE__, :find_claim_reward_pools, [socket, staker, staking_contract_address])
          %{
            html: "OK",
            socket: assign(socket, @searching_claim_reward_pools, %{task: task, staker: staker})
          }
        end

        {:reply, {:ok, %{html: result.html}}, result.socket}
    end
  end

  def handle_in("render_claim_withdrawal", %{"address" => staking_address}, socket) do
    pool = Chain.staking_pool(staking_address)
    token = ContractState.get(:token)
    delegator = Chain.staking_pool_delegator(staking_address, socket.assigns.account)

    html =
      View.render_to_string(StakesView, "_stakes_modal_claim_withdrawal.html",
        token: token,
        delegator: delegator,
        pool: pool
      )

    result = %{
      html: html,
      self_staked_amount: pool.self_staked_amount,
      total_staked_amount: pool.total_staked_amount
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, socket) do
    s = socket.assigns[@searching_claim_reward_pools]
    socket = if s && s.task.ref == ref && s.task.pid == pid do
      :ets.delete(ContractState, searching_claim_reward_pools_key(s.staker))
      assign(socket, @searching_claim_reward_pools, nil)
    else
      socket
    end
    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def handle_out("staking_update", data, socket) do
    push(socket, "staking_update", %{
      block_number: data.block_number,
      epoch_number: data.epoch_number,
      staking_allowed: data.staking_allowed,
      staking_token_defined: data.staking_token_defined,
      validator_set_apply_block: data.validator_set_apply_block,
      top_html: StakesController.render_top(socket)
    })

    {:noreply, socket}
  end

  def find_claim_reward_pools(socket, staker, staking_contract_address) do
    :ets.insert(ContractState, {searching_claim_reward_pools_key(staker), true})
    try do
      staker_padded = address_pad_to_64(staker)
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      # Search for `PlacedStake` events
      {error, pools_staked_into} = find_claim_reward_pools_by_logs(staking_contract_address, [
        # keccak-256 of `PlacedStake(address,address,uint256,uint256)`
        "0x2273de02cb1f69ba6259d22c4bc22c60e4c94c193265ef6afee324a04a9b6d22",
        nil, # don't filter by `toPoolStakingAddress`
        "0x" <> staker_padded # filter by `staker`
      ], json_rpc_named_arguments)

      # Search for `MovedStake` events
      {error, pools_moved_into} = if error == nil do
        find_claim_reward_pools_by_logs(staking_contract_address, [
          # keccak-256 of `MovedStake(address,address,address,uint256,uint256)`
          "0x4480d8e4b1e9095b94bf513961d26fe1d32386ebdd103d18fe8738cf4b2223ff",
          nil, # don't filter by `toPoolStakingAddress`
          "0x" <> staker_padded # filter by `staker`
        ], json_rpc_named_arguments)
      else
        {error, []}
      end

      {error, pools} = if error == nil do
        pools = Enum.uniq(pools_staked_into ++ pools_moved_into)

        pools_amounts = Enum.map(pools, fn pool_staking_address ->
          ContractReader.call_get_reward_amount(
            staking_contract_address,
            [],
            pool_staking_address,
            staker,
            json_rpc_named_arguments
          )
        end)

        error = Enum.find_value(pools_amounts, fn result ->
          case result do
            {:error, reason} -> error_reason_to_string(reason)
            _ -> nil
          end
        end)

        pools = if error != nil do
          %{}
        else
          Enum.map(pools_amounts, fn {_, amounts} -> amounts end)
          |> Enum.zip(pools)
          |> Enum.filter(fn {amounts, _} -> amounts.token_reward_sum > 0 || amounts.native_reward_sum > 0 end)
          |> Map.new(fn {val, key} -> {key, val} end)
        end

        {error, pools}
      else
        {error, %{}}
      end

      html = View.render_to_string(
        StakesView,
        "_stakes_modal_claim_reward_content.html",
        coin: %Token{symbol: Explorer.coin(), decimals: Decimal.new(18)},
        error: error,
        pools: pools,
        token: ContractState.get(:token)
      )

      push(socket, "claim_reward_pools", %{
        html: html
      })
    after
      :ets.delete(ContractState, searching_claim_reward_pools_key(staker))
    end
  end

  defp find_claim_reward_pools_by_logs(staking_contract_address, topics, json_rpc_named_arguments) do
    result = EthereumJSONRPC.request(%{
      id: 0,
      method: "eth_getLogs",
      params: [%{
        fromBlock: "0x0",
        toBlock: "latest",
        address: staking_contract_address,
        topics: topics
      }]
    }) |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)
    case result do
      {:ok, response} ->
        pools = Enum.uniq(Enum.map(response, fn event -> 
          truncate_address(Enum.at(event["topics"], 1))
        end))
        {nil, pools}
      {:error, reason} ->
        {error_reason_to_string(reason), []}
    end
  end

  defp address_pad_to_64(address) do
    address
    |> String.replace_leading("0x", "")
    |> String.pad_leading(64, ["0"])
  end

  defp error_reason_to_string(reason) do
    if is_map(reason) && Map.has_key?(reason, :message) && String.length(String.trim(reason.message)) > 0 do
      reason.message
    else
      gettext("JSON RPC error") <> ": " <> inspect(reason)
    end
  end

  defp push_staking_contract(socket) do
    if socket.assigns[:contract_sent] do
      socket
    else
      token = ContractState.get(:token)

      push(socket, "contracts", %{
        staking_contract: ContractState.get(:staking_contract),
        block_reward_contract: ContractState.get(:block_reward_contract),
        token_decimals: to_string(token.decimals),
        token_symbol: token.symbol
      })

      assign(socket, :contract_sent, true)
    end
  end

  defp searching_claim_reward_pools_key(staker) do
    staker = if staker == nil, do: "", else: staker
    Atom.to_string(@searching_claim_reward_pools) <> "_" <> staker
  end

  defp truncate_address("0x000000000000000000000000" <> truncated_address) do
    "0x#{truncated_address}"
  end
end
