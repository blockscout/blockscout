defmodule BlockScoutWeb.StakesChannel do
  @moduledoc """
  Establishes pub/sub channel for staking page live updates.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.{StakesController, StakesView}
  alias Explorer.Chain
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

    handle_out("staking_update", nil, socket)
  end

  def handle_in("render_validator_info", %{"address" => staking_address}, socket) do
    pool = Chain.staking_pool(staking_address)
    average_block_time = AverageBlockTime.average_block_time()
    token = ContractState.get(:token)

    html =
      View.render_to_string(StakesView, "_stakes_modal_validator_info.html",
        validator: pool,
        average_block_time: average_block_time,
        token: token
      )

    {:reply, {:ok, %{html: html}}, socket}
  end

  def handle_in("render_delegators_list", %{"address" => staking_address}, socket) do
    pool = Chain.staking_pool(staking_address)
    token = ContractState.get(:token)

    delegators =
      staking_address
      |> Chain.staking_pool_delegators()
      |> Enum.sort_by(&(to_string(&1.delegator_address_hash) != socket.assigns[:account]))

    html =
      View.render_to_string(StakesView, "_stakes_modal_delegators_list.html",
        account: socket.assigns[:account],
        pool: pool,
        delegators: delegators,
        token: token
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
      min_candidate_stake: min_candidate_stake
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_in("render_make_stake", %{"address" => staking_address}, socket) do
    pool = Chain.staking_pool(staking_address)
    min_delegator_stake = ContractState.get(:min_delegator_stake)
    token = ContractState.get(:token)
    balance = Chain.fetch_last_token_balance(socket.assigns.account, token.contract_address_hash)

    html =
      View.render_to_string(StakesView, "_stakes_modal_stake.html",
        min_delegator_stake: min_delegator_stake,
        balance: balance,
        token: token,
        pool: pool
      )

    result = %{
      html: html,
      min_delegator_stake: min_delegator_stake,
      self_staked_amount: pool.self_staked_amount,
      staked_amount: pool.staked_amount
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_in("render_move_stake", %{"from" => from_address, "to" => to_address, "amount" => amount}, socket) do
    pool_from = Chain.staking_pool(from_address)
    pool_to = to_address && Chain.staking_pool(to_address)
    pools = Chain.staking_pools(:active, :all)
    delegator = Chain.staking_pool_delegator(from_address, socket.assigns.account)
    min_delegator_stake = ContractState.get(:min_delegator_stake)
    token = ContractState.get(:token)

    html =
      View.render_to_string(StakesView, "_stakes_modal_move.html",
        token: token,
        pools: pools,
        pool_from: pool_from,
        pool_to: pool_to,
        delegator: delegator,
        amount: amount
      )

    result = %{
      html: html,
      min_delegator_stake: min_delegator_stake,
      max_withdraw_allowed: delegator.max_withdraw_allowed,
      from_self_staked_amount: pool_from.self_staked_amount,
      from_staked_amount: pool_from.staked_amount,
      to_self_staked_amount: pool_to && pool_to.self_staked_amount,
      to_staked_amount: pool_to && pool_to.staked_amount
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_in("render_withdraw_stake", %{"address" => staking_address}, socket) do
    pool = Chain.staking_pool(staking_address)
    token = ContractState.get(:token)
    delegator = Chain.staking_pool_delegator(staking_address, socket.assigns.account)
    epoch_number = ContractState.get(:epoch_number, 0)

    claim_html =
      if Decimal.positive?(delegator.ordered_withdraw) and delegator.ordered_withdraw_epoch < epoch_number do
        View.render_to_string(StakesView, "_stakes_modal_claim.html",
          token: token,
          delegator: delegator,
          pool: pool
        )
      end

    html =
      View.render_to_string(StakesView, "_stakes_modal_withdraw.html",
        token: token,
        delegator: delegator,
        pool: pool
      )

    result = %{
      claim_html: claim_html,
      html: html,
      self_staked_amount: pool.self_staked_amount,
      staked_amount: pool.staked_amount
    }

    {:reply, {:ok, result}, socket}
  end

  def handle_out("staking_update", _data, socket) do
    push(socket, "staking_update", %{
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
