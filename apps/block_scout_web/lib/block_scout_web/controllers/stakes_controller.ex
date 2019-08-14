defmodule BlockScoutWeb.StakesController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.StakesView
  alias Explorer.Chain
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Token
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Staking.ContractState
  alias Phoenix.View

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  def index(%{assigns: assigns} = conn, params) do
    render_template(assigns.filter, conn, params)
  end

  def render_top(conn) do
    epoch_number = ContractState.get(:epoch_number, 0)
    epoch_end_block = ContractState.get(:epoch_end_block, 0)
    block_number = BlockNumber.get_max()
    token = ContractState.get(:token, %Token{})

    account =
      if account_address = conn.assigns[:account] do
        %{
          address: account_address,
          balance: Chain.fetch_last_token_balance(account_address, token.contract_address_hash),
          staked: Chain.get_total_staked(account_address),
          pool: Chain.staking_pool(account_address)
        }
      end

    View.render_to_string(StakesView, "_stakes_top.html",
      epoch_number: epoch_number,
      epoch_end_in: epoch_end_block - block_number,
      block_number: block_number,
      account: account,
      token: token
    )
  end

  defp render_template(filter, conn, %{"type" => "JSON"} = params) do
    [paging_options: options] = paging_options(params)

    last_index =
      params
      |> Map.get("position", "0")
      |> String.to_integer()

    pools_plus_one = Chain.staking_pools(filter, options, params["account"])

    {pools, next_page} = split_list_by_page(pools_plus_one)

    next_page_path =
      case next_page_params(next_page, pools, params) do
        nil ->
          nil

        next_page_params ->
          updated_page_params =
            next_page_params
            |> Map.delete("type")
            |> Map.put("position", last_index + 1)

          next_page_path(filter, conn, updated_page_params)
      end

    average_block_time = AverageBlockTime.average_block_time()
    token = ContractState.get(:token, %Token{})
    epoch_number = ContractState.get(:epoch_number, 0)

    items =
      pools
      |> Enum.with_index(last_index + 1)
      |> Enum.map(fn {%{pool: pool, delegator: delegator}, index} ->
        View.render_to_string(
          StakesView,
          "_rows.html",
          token: token,
          pool: pool,
          index: index,
          average_block_time: average_block_time,
          pools_type: filter,
          buttons: %{
            stake: true,
            move: move_allowed?(delegator),
            withdraw: withdraw_allowed?(delegator, epoch_number)
          }
        )
      end)

    json(
      conn,
      %{
        items: items,
        next_page_path: next_page_path
      }
    )
  end

  defp render_template(filter, conn, _) do
    render(conn, "index.html",
      top: render_top(conn),
      pools_type: filter,
      current_path: current_path(conn),
      average_block_time: AverageBlockTime.average_block_time(),
      refresh_interval: Application.get_env(:block_scout_web, BlockScoutWeb.Chain)[:staking_table_refresh_interval]
    )
  end

  defp next_page_path(:validator, conn, params) do
    validators_path(conn, :index, params)
  end

  defp next_page_path(:active, conn, params) do
    active_pools_path(conn, :index, params)
  end

  defp next_page_path(:inactive, conn, params) do
    inactive_pools_path(conn, :index, params)
  end

  defp move_allowed?(nil), do: false

  defp move_allowed?(delegator) do
    delegator.is_active and Decimal.positive?(delegator.max_withdraw_allowed)
  end

  defp withdraw_allowed?(nil, _epoch_number), do: false

  defp withdraw_allowed?(delegator, epoch_number) do
    (delegator.is_active and Decimal.positive?(delegator.max_withdraw_allowed)) or
      (delegator.is_active and Decimal.positive?(delegator.max_ordered_withdraw_allowed)) or
      (Decimal.positive?(delegator.ordered_withdraw) and delegator.ordered_withdraw_epoch < epoch_number)
  end
end
