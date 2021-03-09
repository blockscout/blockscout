defmodule BlockScoutWeb.StakesController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.StakesView
  alias Explorer.Chain
  alias Explorer.Chain.{Cache.BlockNumber, Hash, Token}
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Staking.ContractState
  alias Phoenix.View
  alias Timex.Duration

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  def index(%{assigns: assigns} = conn, params) do
    render_template(assigns.filter, conn, params)
  end

  # this is called when account in MetaMask is changed on client side (see `staking_update` event handled in `StakesChannel`),
  # when a new block appears (see `staking_update` event handled in `StakesChannel`),
  # or when the page is loaded for the first time or reloaded by a user (i.e. it is called by the `render_template(filter, conn, _)`)
  def render_top(conn) do
    staking_data =
      case Map.fetch(conn.assigns, :staking_update_data) do
        {:ok, data} ->
          data

        _ ->
          %{
            active_pools_length: ContractState.get(:active_pools_length, 0),
            block_number: BlockNumber.get_max(),
            epoch_end_block: ContractState.get(:epoch_end_block, 0),
            epoch_number: ContractState.get(:epoch_number, 0),
            max_candidates: ContractState.get(:max_candidates, 0)
          }
      end

    token = ContractState.get(:token, %Token{})

    account =
      if account_address = conn.assigns[:account] do
        account_address
        |> Chain.get_total_staked_and_ordered()
        |> Map.merge(%{
          address: account_address,
          balance: Chain.fetch_last_token_balance(account_address, token.contract_address_hash),
          pool: Chain.staking_pool(account_address),
          pool_mining_address: conn.assigns[:mining_address]
        })
      end

    epoch_end_in =
      if staking_data.epoch_end_block - staking_data.block_number >= 0,
        do: staking_data.epoch_end_block - staking_data.block_number,
        else: 0

    View.render_to_string(StakesView, "_stakes_top.html",
      account: account,
      block_number: staking_data.block_number,
      candidates_limit_reached: staking_data.active_pools_length >= staking_data.max_candidates,
      epoch_end_in: epoch_end_in,
      epoch_number: staking_data.epoch_number,
      token: token
    )
  end

  # this is called when account in MetaMask is changed on client side
  # or when UI periodically reloads the pool list (e.g. once per 10 blocks)
  defp render_template(filter, conn, %{"type" => "JSON"} = params) do
    {items, next_page_path} =
      if Map.has_key?(params, "filterMy") do
        [paging_options: options] = paging_options(params)

        # turn off paging for Validators page as we sort by APY below
        # and max number of validators is no more than 19
        # (for the current POSDAO implementation)
        options =
          if is_page_unlimited?(filter) do
            Map.put(options, :page_size, 1_000_000)
          else
            options
          end

        pools_plus_one =
          Chain.staking_pools(
            filter,
            options,
            unless params["account"] == "" do
              params["account"]
            end,
            params["filterBanned"] == "true",
            params["filterMy"] == "true"
          )

        {pools, next_page_path, last_index} = get_one_page(filter, conn, params, pools_plus_one)

        average_block_time = AverageBlockTime.average_block_time()

        average_block_time_seconds =
          try do
            Duration.to_seconds(average_block_time)
          rescue
            _ -> nil
          end

        staking_epoch_duration = ContractState.staking_epoch_duration()
        token = ContractState.get(:token, %Token{})
        epoch_number = ContractState.get(:epoch_number, 0)
        staking_allowed = ContractState.get(:staking_allowed, false)
        pool_rewards = ContractState.get(:pool_rewards, %{})
        calc_apy_enabled = ContractState.calc_apy_enabled?()
        snapshotted_delegator_data = snapshotted_delegator_data(filter, calc_apy_enabled)

        pools =
          pools
          |> Enum.map(fn %{pool: pool} = item ->
            apy =
              if calc_apy_enabled and snapshotted_delegator_data !== nil do
                calc_apy(
                  item.pool,
                  pool_rewards,
                  snapshotted_delegator_data,
                  average_block_time_seconds,
                  staking_epoch_duration
                )
              end

            pool = Map.put(pool, :apy, apy)
            Map.put(item, :pool, pool)
          end)

        # sort pools on Validators page by descending APY if all APYs known
        pools = sort_pools_by_apy(pools)

        items =
          pools
          |> Enum.with_index(last_index + 1)
          |> Enum.map(fn {%{pool: pool, delegator: delegator}, index} ->
            View.render_to_string(
              StakesView,
              "_rows.html",
              token: token,
              pool: pool,
              delegator: delegator,
              index: index,
              average_block_time: average_block_time,
              pools_type: filter,
              buttons: staking_buttons(pool, delegator, staking_allowed, epoch_number)
            )
          end)

        {items, next_page_path}
      else
        loading_item = View.render_to_string(StakesView, "_rows_loading.html", %{})
        {[loading_item], nil}
      end

    json(
      conn,
      %{
        items: items,
        next_page_path: next_page_path
      }
    )
  end

  # this is called when the page is loaded for the first time
  # or when it is reloaded by a user
  defp render_template(filter, conn, _) do
    token = ContractState.get(:token, %Token{})

    render(conn, "index.html",
      top: render_top(conn),
      token: token,
      pools_type: filter,
      current_path: current_path(conn),
      average_block_time: AverageBlockTime.average_block_time(),
      refresh_interval: Application.get_env(:block_scout_web, BlockScoutWeb.Chain)[:staking_pool_list_refresh_interval]
    )
  end

  defp staking_buttons(pool, delegator, staking_allowed, epoch_number) do
    %{
      stake: staking_allowed and stake_allowed?(pool, delegator),
      move: staking_allowed and move_allowed?(delegator),
      withdraw: staking_allowed and withdraw_allowed?(delegator),
      claim: staking_allowed and claim_allowed?(delegator, epoch_number)
    }
  end

  defp calc_apy(pool, pool_rewards, snapshotted_delegator_data, average_block_time, staking_epoch_duration) do
    staking_address_str = String.downcase(Hash.to_string(pool.staking_address_hash))
    mining_address_str = String.downcase(Hash.to_string(pool.mining_address_hash))

    pool_reward =
      case Map.fetch(pool_rewards, mining_address_str) do
        {:ok, pool_reward} -> pool_reward
        :error -> nil
      end

    case Map.fetch(snapshotted_delegator_data, staking_address_str) do
      {:ok, data} ->
        ContractState.calc_apy(
          data.snapshotted_reward_ratio,
          pool_reward,
          data.snapshotted_stake_amount,
          average_block_time,
          staking_epoch_duration
        )

      :error ->
        ContractState.calc_apy(
          pool.snapshotted_validator_reward_ratio,
          pool_reward,
          pool.snapshotted_self_staked_amount,
          average_block_time,
          staking_epoch_duration
        )
    end
  end

  defp snapshotted_delegator_data(filter, calc_apy_enabled) do
    if filter == :validator and calc_apy_enabled do
      Chain.staking_pool_snapshotted_delegator_data_for_apy()
      |> Enum.reduce(%{}, fn item, acc ->
        staking_address_str = address_bytes_to_string(item.staking_address_hash)
        Map.put(acc, staking_address_str, item)
      end)
    end
  end

  defp sort_pools_by_apy(pools) do
    if Enum.all?(pools, fn item -> item.pool.apy !== nil end) do
      Enum.sort(pools, fn item1, item2 -> item1.pool.apy.apy_raw >= item2.pool.apy.apy_raw end)
    else
      pools
    end
  end

  defp address_bytes_to_string(hash), do: "0x" <> Base.encode16(hash, case: :lower)

  defp get_one_page(filter, conn, params, pools_plus_one) do
    last_index =
      params
      |> Map.get("position", "0")
      |> String.to_integer()

    {pools, next_page} =
      if is_page_unlimited?(filter) do
        {pools_plus_one, []}
      else
        split_list_by_page(pools_plus_one)
      end

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

    {pools, next_page_path, last_index}
  end

  defp is_page_unlimited?(filter) do
    filter == :validator
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

  defp stake_allowed?(pool, nil) do
    Decimal.positive?(pool.self_staked_amount)
  end

  defp stake_allowed?(pool, delegator) do
    Decimal.positive?(pool.self_staked_amount) or delegator.address_hash == pool.staking_address_hash
  end

  defp move_allowed?(nil), do: false

  defp move_allowed?(delegator) do
    Decimal.positive?(delegator.max_withdraw_allowed)
  end

  defp withdraw_allowed?(nil), do: false

  defp withdraw_allowed?(delegator) do
    Decimal.positive?(delegator.max_withdraw_allowed) or
      Decimal.positive?(delegator.max_ordered_withdraw_allowed) or
      Decimal.positive?(delegator.ordered_withdraw)
  end

  defp claim_allowed?(nil, _epoch_number), do: false

  defp claim_allowed?(delegator, epoch_number) do
    Decimal.positive?(delegator.ordered_withdraw) and delegator.ordered_withdraw_epoch < epoch_number
  end
end
