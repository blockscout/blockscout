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
