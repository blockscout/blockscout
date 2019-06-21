defmodule BlockScoutWeb.PoolsController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.{BlockNumberCache, Wei}
  alias Explorer.Counters.AverageBlockTime
  alias BlockScoutWeb.{PoolsView, StakesView}
  alias Explorer.Staking.{EpochCounter, PoolsReader}
  alias Phoenix.View

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  @accesses [:stake, :withdraw, :order_withdraw, :claim]

  def index(%{assigns: assigns} = conn, params) do
    render_template(assigns.filter, conn, params)
  end

  def set_session(conn, %{"address" => address}) do
    case Chain.string_to_address_hash(address) do
      {:ok, _address} ->
        conn
        |> put_session(:address_hash, address)
        |> json(%{success: true})

      _ ->
        conn
        |> delete_session(:address_hash)
        |> json(%{success: true})
    end
  end

  def delegator(conn, %{"address" => address}) do
    with {:ok, hash} <- Chain.string_to_address_hash(address),
         delegator when is_map(delegator) <- delegator_info(hash) do
      json(conn, %{delegator: delegator})
    else
      _ ->
        json(conn, %{delegator: nil})
    end
  end

  def staking_contract(conn, _) do
    staking_address = PoolsReader.get_staking_address()
    staking_abi = PoolsReader.get_staking_abi()

    json(conn, %{abi: staking_abi, address: staking_address})
  end

  def staking_pool(conn, %{"pool_hash" => pool_hash}) do
    case Chain.staking_pool(pool_hash) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{success: false})

      pool ->
        user_address = get_session(conn, :address_hash)

        pool =
          Map.merge(pool, %{
            staked_amount: Wei.to(pool.staked_amount, :ether),
            self_staked_amount: Wei.to(pool.self_staked_amount, :ether)
          })

        if user_address do
          relation = Chain.staking_delegator(user_address, pool.staking_address_hash)

          if relation do
            prepared_relation =
              relation
              |> Map.update!(:stake_amount, &Wei.to(&1, :ether))
              |> Map.update!(:ordered_withdraw, &Wei.to(&1, :ether))
              |> Map.update!(:max_withdraw_allowed, &Wei.to(&1, :ether))
              |> Map.update!(:max_ordered_withdraw_allowed, &Wei.to(&1, :ether))

            json(conn, %{pool: pool, relation: prepared_relation})
          else
            json(conn, %{pool: pool})
          end
        else
          json(conn, %{pool: pool})
        end
    end
  end

  def staking_pools(conn, _) do
    active_pools = Chain.staking_pools(:active)
    json(conn, %{pools: active_pools})
  end

  defp render_template(_, conn, %{"type" => "JSON", "template" => "top"}) do
    epoch_number = EpochCounter.epoch_number() || 0
    epoch_end_block = EpochCounter.epoch_end_block() || 0
    block_number = BlockNumberCache.max_number()
    stakes_setting = Application.get_env(:block_scout_web, :stakes)

    user =
      conn
      |> get_session(:address_hash)
      |> delegator_info()

    options = [
      epoch_number: epoch_number,
      epoch_end_in: epoch_end_block - block_number,
      block_number: block_number,
      user: user,
      logged_in: user != nil,
      min_candidate_stake: stakes_setting[:min_candidate_stake]
    ]

    content =
      View.render_to_string(
        StakesView,
        "_stakes_top.html",
        options
      )

    json(conn, %{content: content})
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

    items =
      pools
      |> Enum.with_index(last_index + 1)
      |> Enum.map(fn {pool, index} ->
        View.render_to_string(
          PoolsView,
          "_rows.html",
          pool: pool,
          index: index,
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

  defp render_template(filter, conn, _) do
    epoch_number = EpochCounter.epoch_number() || 0
    epoch_end_block = EpochCounter.epoch_end_block() || 0
    block_number = BlockNumberCache.max_number()
    average_block_time = AverageBlockTime.average_block_time()
    stakes_setting = Application.get_env(:block_scout_web, :stakes)

    user =
      conn
      |> get_session(:address_hash)
      |> delegator_info()

    options = [
      pools_type: filter,
      epoch_number: epoch_number,
      epoch_end_in: epoch_end_block - block_number,
      block_number: block_number,
      current_path: current_path(conn),
      user: user,
      logged_in: user != nil,
      average_block_time: average_block_time,
      min_candidate_stake: stakes_setting[:min_candidate_stake],
      min_delegator_stake: stakes_setting[:min_delegator_stake]
    ]

    render(conn, "index.html", options)
  end

  defp delegator_info(address) when not is_nil(address) do
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

  defp delegator_info(_), do: nil

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

  defp next_page_path(:validator, conn, params) do
    validators_path(conn, :index, params)
  end

  defp next_page_path(:active, conn, params) do
    active_pools_path(conn, :index, params)
  end

  defp next_page_path(:inactive, conn, params) do
    inactive_pools_path(conn, :index, params)
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
end
