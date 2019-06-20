defmodule BlockScoutWeb.PoolsController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.{BlockNumberCache, Wei}
  alias Explorer.Counters.AverageBlockTime
  alias BlockScoutWeb.{CommonComponentsView, PoolsView, StakesView}
  alias Explorer.Staking.{EpochCounter, PoolsReader}
  alias Phoenix.View

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  @accesses [:stake, :withdraw, :order_withdraw, :claim]

  def validators(conn, params) do
    render_template(:validator, conn, params)
  end

  def active_pools(conn, params) do
    render_template(:active, conn, params)
  end

  def inactive_pools(conn, params) do
    render_template(:inactive, conn, params)
  end

  defp render_template(_, conn, %{"modal_window" => window_name, "pool_hash" => pool_hash} = params) do
    window =
      pool_hash
      |> Chain.staking_pool()
      |> render_modal(window_name, params, conn)

    json(conn, %{window: window})
  end

  defp render_template(_, conn, %{"command" => "set_session", "address" => address}) do
    if get_session(conn, :address_hash) == address do
      json(conn, %{reload: false})
    else
      case Chain.string_to_address_hash(address) do
        {:ok, _address} ->
          conn
          |> put_session(:address_hash, address)
          |> json(%{reload: true})

        _ ->
          conn
          |> delete_session(:address_hash)
          |> json(%{reload: true})
      end
    end
  end

  defp render_template(filter, conn, %{"type" => "JSON"} = params) do
    [paging_options: options] = paging_options(params)
    user_address = get_session(conn, :address_hash)

    last_index =
      params
      |> Map.get("position", "0")
      |> String.to_integer()

    pools_plus_one =
      if user_address do
        filter
        |> Chain.staking_pools_with_staker(user_address, options)
        |> Enum.map(fn {pool, delegator} ->
          accesses = get_accesses(delegator)
          Map.put(pool, :accesses, accesses)
        end)
      else
        Chain.staking_pools(filter, options)
      end

    pools_with_index =
      pools_plus_one
      |> Enum.with_index(last_index + 1)
      |> Enum.map(fn {pool, index} ->
        Map.put(pool, :position, index)
      end)

    {pools, next_page} = split_list_by_page(pools_with_index)

    next_page_path =
      case next_page_params(next_page, pools, params) do
        nil ->
          nil

        next_page_params ->
          next_page_path(filter, conn, Map.delete(next_page_params, "type"))
      end

    average_block_time = AverageBlockTime.average_block_time()

    items =
      pools
      |> Enum.map(fn pool ->
        View.render_to_string(
          PoolsView,
          "_rows.html",
          pool: pool,
          average_block_time: average_block_time,
          pools_type: filter,
          accesses: Map.get(pool, :accesses, [])
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

  defp render_template(filter, conn, %{"template" => "stakes_top"}) do
    epoch_number = EpochCounter.epoch_number() || 0
    epoch_end_block = EpochCounter.epoch_end_block() || 0
    block_number = BlockNumberCache.max_number()
    user = gelegator_info(conn)
    stakes_setting = Application.get_env(:block_scout_web, :stakes)
    staking_address = PoolsReader.get_staking_address()
    staking_abi = PoolsReader.get_staking_abi()
    validators_address = PoolsReader.get_validators_address()
    validators_abi = PoolsReader.get_validators_abi()
    average_block_time = AverageBlockTime.average_block_time()

    options = [
      pools_type: filter,
      epoch_number: epoch_number,
      epoch_end_in: epoch_end_block - block_number,
      block_number: block_number,
      current_path: current_path(conn),
      user: user,
      logged_in: user != nil,
      min_candidate_stake: stakes_setting[:min_candidate_stake],
      staking_address: staking_address,
      staking_abi: Poison.encode!(staking_abi),
      validators_address: validators_address,
      validators_abi: Poison.encode!(validators_abi),
      average_block_time: average_block_time
    ]

    content = View.render_to_string(
      StakesView,
      "_stakes_top.html",
      options
    )

    json(conn, %{content: content})
  end

  defp render_template(filter, conn, _) do
    epoch_number = EpochCounter.epoch_number() || 0
    epoch_end_block = EpochCounter.epoch_end_block() || 0
    block_number = BlockNumberCache.max_number()
    user = gelegator_info(conn)
    stakes_setting = Application.get_env(:block_scout_web, :stakes)
    staking_address = PoolsReader.get_staking_address()
    staking_abi = PoolsReader.get_staking_abi()
    validators_address = PoolsReader.get_validators_address()
    validators_abi = PoolsReader.get_validators_abi()
    average_block_time = AverageBlockTime.average_block_time()

    options = [
      pools_type: filter,
      epoch_number: epoch_number,
      epoch_end_in: epoch_end_block - block_number,
      block_number: block_number,
      current_path: current_path(conn),
      user: user,
      logged_in: user != nil,
      min_candidate_stake: stakes_setting[:min_candidate_stake],
      staking_address: staking_address,
      staking_abi: Poison.encode!(staking_abi),
      validators_address: validators_address,
      validators_abi: Poison.encode!(validators_abi),
      average_block_time: average_block_time
    ]

    render(conn, "index.html", options)
  end

  defp gelegator_info(conn) do
    address = get_session(conn, :address_hash)

    if address do
      case Chain.delegator_info(address) do
        [staked, self_staked, has_pool] ->
          {:ok, staked_wei} = Wei.cast(staked || 0)
          {:ok, self_staked_wei} = Wei.cast(self_staked || 0)

          staked_sum = Wei.sum(staked_wei, self_staked_wei)
          stakes_token_name = System.get_env("STAKES_TOKEN_NAME") || "POSDAO"

          %{
            address: address,
            balance: get_token_balance(address, stakes_token_name),
            staked: staked_sum,
            has_pool: has_pool
          }

        _ ->
          {:ok, zero_wei} = Wei.cast(0)

          %{
            address: address,
            balance: zero_wei,
            staked: zero_wei,
            has_pool: false
          }
      end
    end
  end

  defp get_token_balance(address, token_name) do
    {:ok, balance} =
      address
      |> Chain.address_tokens_with_balance()
      |> Enum.find_value(Wei.cast(0), fn token ->
        if token.name == token_name do
          Wei.cast(token.balance)
        end
      end)

    balance
  end

  defp get_accesses(delegator) do
    Enum.reduce(@accesses, [], fn access, acc ->
      if check_access(delegator, access) do
        [access | acc]
      else
        acc
      end
    end)
  end

  defp check_access(%{max_withdraw_allowed: max, is_active: true}, :withdraw) do
    Decimal.to_float(max.value) > 0
  end

  defp check_access(%{max_ordered_withdraw_allowed: max, is_active: true}, :order_withdraw) do
    Decimal.to_float(max.value) > 0
  end

  defp check_access(%{ordered_withdraw: amount, ordered_withdraw_epoch: epoch}, :claim) do
    Decimal.to_float(amount.value) > 0 && epoch < (EpochCounter.epoch_number() || 0)
  end

  defp check_access(_, :stake), do: true

  defp check_access(_, _), do: false

  defp next_page_path(:validator, conn, params) do
    validators_path(conn, :validators, params)
  end

  defp next_page_path(:active, conn, params) do
    active_pools_path(conn, :active_pools, params)
  end

  defp next_page_path(:inactive, conn, params) do
    inactive_pools_path(conn, :inactive_pools, params)
  end

  defp render_modal(pool, "info", _params, _conn) do
    average_block_time = AverageBlockTime.average_block_time()

    View.render_to_string(
      StakesView,
      "_stakes_modal_validator_info.html",
      validator: pool,
      average_block_time: average_block_time
    )
  end

  defp render_modal(pool, "make_stake", _params, conn) do
    delegator = gelegator_info(conn)
    stakes_setting = Application.get_env(:block_scout_web, :stakes)

    if delegator do
      View.render_to_string(
        StakesView,
        "_stakes_modal_stake.html",
        pool: pool,
        balance: delegator[:balance],
        min_stake: stakes_setting[:min_delegator_stake]
      )
    else
      View.render_to_string(
        CommonComponentsView,
        "_modal_status.html",
        status: "error",
        title: "Unauthorized"
      )
    end
  end

  defp render_modal(pool, "withdraw", _params, conn) do
    with address when is_binary(address) <- get_session(conn, :address_hash),
         delegator when is_map(delegator) <- Chain.staking_delegator(address, pool.staking_address_hash) do
      View.render_to_string(
        StakesView,
        "_stakes_modal_withdraw.html",
        pool: pool,
        accesses: get_accesses(delegator),
        staked: delegator.stake_amount
      )
    else
      _ ->
        View.render_to_string(
          CommonComponentsView,
          "_modal_status.html",
          status: "error",
          title: "Unauthorized"
        )
    end
  end

  defp render_modal(pool, "claim", _params, conn) do
    with address when is_binary(address) <- get_session(conn, :address_hash),
         delegator when is_map(delegator) <- Chain.staking_delegator(address, pool.staking_address_hash) do
      View.render_to_string(
        StakesView,
        "_stakes_modal_claim.html",
        pool: pool,
        ordered_amount: delegator.ordered_withdraw
      )
    else
      _ ->
        View.render_to_string(
          CommonComponentsView,
          "_modal_status.html",
          status: "error",
          title: "Unauthorized"
        )
    end
  end

  defp render_modal(%{staking_address_hash: pool_address} = pool, "move_stake", _params, conn) do
    with address when is_binary(address) <- get_session(conn, :address_hash),
         delegator when is_map(delegator) <- Chain.staking_delegator(address, pool_address) do
      pools =
        :active
        |> Chain.staking_pools()
        |> Enum.filter(&(&1.staking_address_hash != pool_address))
        |> Enum.map(fn %{staking_address_hash: hash} ->
          string_hash = to_string(hash)

          [
            key: binary_part(string_hash, 0, 13),
            value: string_hash
          ]
        end)

      View.render_to_string(
        StakesView,
        "_stakes_modal_move.html",
        pool: pool,
        pools: pools,
        staked: delegator.stake_amount
      )
    else
      _ ->
        View.render_to_string(
          CommonComponentsView,
          "_modal_status.html",
          status: "error",
          title: "Unauthorized"
        )
    end
  end

  defp render_modal(%{staking_address_hash: pool_address} = pool, "move_selected", params, conn) do
    with address when is_binary(address) <- get_session(conn, :address_hash),
         delegator when is_map(delegator) <- Chain.staking_delegator(address, pool_address) do
      pools =
        :active
        |> Chain.staking_pools()
        |> Enum.filter(&(&1.staking_address_hash != pool_address))
        |> Enum.map(fn %{staking_address_hash: hash} ->
          string_hash = to_string(hash)

          [
            key: binary_part(string_hash, 0, 13),
            value: string_hash
          ]
        end)

      pool_to =
        params
        |> Map.get("pool_to")
        |> Chain.staking_pool()

      View.render_to_string(
        StakesView,
        "_stakes_modal_move_selected.html",
        pool_from: pool,
        pool_to: pool_to,
        pools: pools,
        staked: delegator.stake_amount
      )
    else
      _ ->
        View.render_to_string(
          CommonComponentsView,
          "_modal_status.html",
          status: "error",
          title: "Unauthorized"
        )
    end
  end
end
