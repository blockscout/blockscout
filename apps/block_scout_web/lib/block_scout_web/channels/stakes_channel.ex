defmodule BlockScoutWeb.StakesChannel do
  @moduledoc """
  Establishes pub/sub channel for staking page live updates.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.{StakesController, StakesView}
  alias Explorer.Chain
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Staking.ContractState
  alias Phoenix.View

  intercept(["staking_update"])

  def join("stakes:staking_update", _params, socket) do
    {:ok, %{}, socket}
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
        staking_allowed: ContractState.get(:staking_allowed, false),
        epoch_number: ContractState.get(:epoch_number, 0)
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
      View.render_to_string(StakesView, "_stakes_modal_validator_info.html",
        validator: pool,
        delegator: delegator,
        average_block_time: average_block_time,
        token: token
      )

    {:reply, {:ok, %{html: html}}, socket}
  end

  def handle_in("render_delegators_list", %{"address" => staking_address}, socket) do
    pool = Chain.staking_pool(staking_address)
    token = ContractState.get(:token)
    validator_set_apply_block = ContractState.get(:validator_set_apply_block)

    delegators =
      staking_address
      |> Chain.staking_pool_delegators()
      |> Enum.sort_by(fn delegator ->
        delegator_address = to_string(delegator.delegator_address_hash)

        cond do
          delegator_address == staking_address -> 0
          delegator_address == socket.assigns[:account] -> 1
          true -> 2
        end
      end)

    html =
      View.render_to_string(StakesView, "_stakes_modal_delegators_list.html",
        account: socket.assigns[:account],
        pool: pool,
        delegators: delegators,
        token: token,
        validator_set_apply_block: validator_set_apply_block
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
      staked_amount: pool.staked_amount
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
      if delegator_from.delegator_address_hash == delegator_from.pool_address_hash do
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
        staked_amount: pool_from.staked_amount
      },
      to:
        if pool_to do
          %{
            stake_amount: (delegator_to && delegator_to.stake_amount) || 0,
            min_stake: min_to_stake,
            self_staked_amount: pool_to.self_staked_amount,
            staked_amount: pool_to.staked_amount
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
      if delegator.delegator_address_hash == delegator.pool_address_hash do
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
      staked_amount: pool.staked_amount,
      delegator_staked: delegator.stake_amount,
      ordered_withdraw: delegator.ordered_withdraw,
      max_withdraw_allowed: delegator.max_withdraw_allowed,
      max_ordered_withdraw_allowed: delegator.max_ordered_withdraw_allowed,
      min_stake: min_stake
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_in("render_claim_withdrawal", %{"address" => staking_address}, socket) do
    pool = Chain.staking_pool(staking_address)
    token = ContractState.get(:token)
    delegator = Chain.staking_pool_delegator(staking_address, socket.assigns.account)

    html =
      View.render_to_string(StakesView, "_stakes_modal_claim.html",
        token: token,
        delegator: delegator,
        pool: pool
      )

    result = %{
      html: html,
      self_staked_amount: pool.self_staked_amount,
      staked_amount: pool.staked_amount
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_out("staking_update", data, socket) do
    push(socket, "staking_update", %{
      epoch_number: data.epoch_number,
      block_number: data.block_number,
      staking_allowed: data.staking_allowed,
      top_html: StakesController.render_top(socket)
    })

    {:noreply, socket}
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
end
