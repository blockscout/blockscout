defmodule BlockScoutWeb.StakesChannel do
  @moduledoc """
  Establishes pub/sub channel for staking page live updates.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.{StakesController, StakesHelpers, StakesView}
  alias Explorer.Chain
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Token
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Staking.{ContractReader, ContractState}
  alias Phoenix.View

  import BlockScoutWeb.Gettext

  @claim_reward_long_op :claim_reward_long_op

  intercept(["staking_update"])

  def join("stakes:staking_update", _params, socket) do
    {:ok, %{}, socket}
  end

  # called when socket is closed on a client side
  # or socket timeout is reached - see `timeout` option in
  # https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-websocket-configuration
  # apps/block_scout_web/lib/block_scout_web/endpoint.ex
  def terminate(_reason, socket) do
    s = socket.assigns[@claim_reward_long_op]

    if s != nil do
      :ets.delete(ContractState, claim_reward_long_op_key(s.staker))
    end
  end

  def handle_in("set_account", account, socket) do
    # fetch mining address by staking address to show `Make stake` modal
    # instead of `Become a candidate` for the staking address which
    # has ever been a pool
    pool_mining_address =
      try do
        validator_set_contract = ContractState.get(:validator_set_contract)

        ContractReader.perform_requests(
          ContractReader.mining_by_staking_request(account),
          %{validator_set: validator_set_contract.address},
          validator_set_contract.abi
        ).mining_address
      rescue
        _ -> nil
      end

    # convert zero address to nil
    mining_address =
      if pool_mining_address != "0x0000000000000000000000000000000000000000" do
        pool_mining_address
      end

    socket =
      socket
      |> assign(:account, account)
      |> assign(:mining_address, mining_address)
      |> push_contracts()

    data =
      case Map.fetch(socket.assigns, :staking_update_data) do
        {:ok, staking_update_data} ->
          staking_update_data

        _ ->
          %{
            block_number: BlockNumber.get_max(),
            epoch_number: ContractState.get(:epoch_number, 0),
            staking_allowed: ContractState.get(:staking_allowed, false),
            staking_token_defined: ContractState.get(:token, nil) != nil,
            validator_set_apply_block: ContractState.get(:validator_set_apply_block, 0)
          }
      end

    handle_out("staking_update", Map.merge(data, %{by_set_account: true}), socket)

    {:reply, :ok, socket}
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
    min_candidate_stake = Decimal.new(ContractState.get(:min_candidate_stake))
    token = ContractState.get(:token)
    balance = Chain.fetch_last_token_balance(socket.assigns.account, token.contract_address_hash)

    html =
      View.render_to_string(StakesView, "_stakes_modal_become_candidate.html",
        min_candidate_stake: min_candidate_stake,
        balance: balance,
        coin: get_coin(),
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
    staking_pool = Chain.staking_pool(staking_address)
    delegator = Chain.staking_pool_delegator(staking_address, socket.assigns.account)
    token = ContractState.get(:token)
    balance = Chain.fetch_last_token_balance(socket.assigns.account, token.contract_address_hash)

    min_stake =
      Decimal.new(
        if staking_address == socket.assigns.account do
          ContractState.get(:min_candidate_stake)
        else
          ContractState.get(:min_delegator_stake)
        end
      )

    delegator_staked = Decimal.new((delegator && delegator.stake_amount) || 0)

    # if pool doesn't exist, fill it with empty values
    # to be able to display _stakes_progress.html.eex template
    pool =
      staking_pool ||
        %{
          delegators_count: 0,
          is_active: false,
          is_deleted: true,
          self_staked_amount: 0,
          mining_address_hash: nil,
          staking_address_hash: staking_address,
          total_staked_amount: 0
        }

    html =
      View.render_to_string(StakesView, "_stakes_modal_stake.html",
        balance: balance,
        delegator_staked: delegator_staked,
        min_stake: min_stake,
        pool: pool,
        token: token
      )

    result = %{
      html: html,
      balance: balance,
      delegator_staked: delegator_staked,
      mining_address: nil,
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

    min_from_stake =
      Decimal.new(
        if delegator_from.address_hash == delegator_from.staking_address_hash do
          ContractState.get(:min_candidate_stake)
        else
          ContractState.get(:min_delegator_stake)
        end
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
          stake_amount = Decimal.new((delegator_to && delegator_to.stake_amount) || 0)

          min_to_stake =
            Decimal.new(
              if to_address == socket.assigns.account do
                ContractState.get(:min_candidate_stake)
              else
                ContractState.get(:min_delegator_stake)
              end
            )

          %{
            stake_amount: stake_amount,
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

    staking_contract_address =
      try do
        ContractState.get(:staking_contract).address
      rescue
        _ -> nil
      end

    empty_staker = staker == nil || staker == "" || staker == "0x0000000000000000000000000000000000000000"

    empty_staking_contract_address =
      staking_contract_address == nil || staking_contract_address == "" ||
        staking_contract_address == "0x0000000000000000000000000000000000000000"

    handle_in_render_claim_reward_result(
      socket,
      data,
      staker,
      staking_contract_address,
      empty_staker,
      empty_staking_contract_address
    )
  end

  def handle_in("recalc_claim_reward", data, socket) do
    epochs = data["epochs"]
    pool_staking_address = data["pool_staking_address"]
    staker = socket.assigns[:account]

    staking_contract_address =
      try do
        ContractState.get(:staking_contract).address
      rescue
        _ -> nil
      end

    empty_pool_staking_address =
      pool_staking_address == nil || pool_staking_address == "" ||
        pool_staking_address == "0x0000000000000000000000000000000000000000"

    empty_staker = staker == nil || staker == "" || staker == "0x0000000000000000000000000000000000000000"

    empty_staking_contract_address =
      staking_contract_address == nil || staking_contract_address == "" ||
        staking_contract_address == "0x0000000000000000000000000000000000000000"

    handle_in_recalc_claim_reward_result(
      socket,
      epochs,
      staking_contract_address,
      pool_staking_address,
      staker,
      empty_pool_staking_address,
      empty_staking_contract_address,
      empty_staker
    )
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
    s = socket.assigns[@claim_reward_long_op]

    socket =
      if s && s.task.ref == ref && s.task.pid == pid do
        :ets.delete(ContractState, claim_reward_long_op_key(s.staker))
        assign(socket, @claim_reward_long_op, nil)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def handle_out("staking_update", data, socket) do
    by_set_account =
      case Map.fetch(data, :by_set_account) do
        {:ok, value} -> value
        _ -> false
      end

    socket =
      if by_set_account do
        # if :by_set_account is in the `data`,
        # it means that this function was called by
        # handle_in("set_account", ...), so we
        # shouldn't assign the incoming data to the socket
        socket
      else
        # otherwise, we should do the assignment
        # to use the incoming data later by
        # handle_in("set_account", ...) and StakesController.render_top
        assign(socket, :staking_update_data, data)
      end

    push(socket, "staking_update", %{
      account: socket.assigns[:account],
      block_number: data.block_number,
      by_set_account: by_set_account,
      epoch_number: data.epoch_number,
      staking_allowed: data.staking_allowed,
      staking_token_defined: data.staking_token_defined,
      validator_set_apply_block: data.validator_set_apply_block,
      top_html: StakesController.render_top(socket)
    })

    {:noreply, socket}
  end

  def find_claim_reward_pools(socket, staker, staking_contract_address) do
    :ets.insert(ContractState, {claim_reward_long_op_key(staker), true})

    try do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
      staking_contract = ContractState.get(:staking_contract)

      responses =
        staker
        |> ContractReader.get_staker_pools_length_request()
        |> ContractReader.perform_requests(%{staking: staking_contract.address}, staking_contract.abi)

      staker_pools_length = responses[:length]

      chunk_size = 100

      pools =
        if staker_pools_length > 0 do
          chunks = 0..trunc(ceil(staker_pools_length / chunk_size) - 1)

          Enum.reduce(chunks, [], fn i, acc ->
            responses =
              staker
              |> ContractReader.get_staker_pools_request(i * chunk_size, chunk_size)
              |> ContractReader.perform_requests(%{staking: staking_contract.address}, staking_contract.abi)

            acc ++
              Enum.map(responses[:pools], fn pool_staking_address ->
                address_bytes_to_string(pool_staking_address)
              end)
          end)
        else
          []
        end

      pools_amounts =
        Enum.map(pools, fn pool_staking_address ->
          ContractReader.call_get_reward_amount(
            staking_contract_address,
            [],
            pool_staking_address,
            staker,
            json_rpc_named_arguments
          )
        end)

      error =
        Enum.find_value(pools_amounts, fn result ->
          case result do
            {:error, reason} -> error_reason_to_string(reason)
            _ -> nil
          end
        end)

      {error, pools} =
        get_pools(pools_amounts, pools, staking_contract_address, staker, json_rpc_named_arguments, error)

      html =
        View.render_to_string(
          StakesView,
          "_stakes_modal_claim_reward_content.html",
          coin: get_coin(),
          error: error,
          pools: pools,
          token: ContractState.get(:token)
        )

      push(socket, "claim_reward_pools", %{
        html: html
      })
    after
      :ets.delete(ContractState, claim_reward_long_op_key(staker))
    end
  end

  def get_pools(pools_amounts, pools, staking_contract_address, staker, json_rpc_named_arguments, error) do
    if error != nil do
      {error, %{}}
    else
      block_reward_contract = ContractState.get(:block_reward_contract)

      pools =
        pools_amounts
        |> Enum.map(fn {_, amounts} -> amounts end)
        |> Enum.zip(pools)
        |> Enum.filter(fn {amounts, _} -> amounts.token_reward_sum > 0 || amounts.native_reward_sum > 0 end)
        |> Enum.map(fn {amounts, pool_staking_address} ->
          responses =
            pool_staking_address
            |> ContractReader.epochs_to_claim_reward_from_request(staker)
            |> ContractReader.perform_requests(
              %{block_reward: block_reward_contract.address},
              block_reward_contract.abi
            )

          epochs =
            responses[:epochs]
            |> array_to_ranges()
            |> Enum.map(fn {first, last} ->
              Integer.to_string(first) <> if first != last, do: "-" <> Integer.to_string(last), else: ""
            end)

          data = Map.put(amounts, :epochs, Enum.join(epochs, ","))

          {data, pool_staking_address}
        end)
        |> Enum.filter(fn {data, _} -> data.epochs != "" end)

      pools_gas_estimates =
        Enum.map(pools, fn {_data, pool_staking_address} ->
          result =
            ContractReader.claim_reward_estimate_gas(
              staking_contract_address,
              [],
              pool_staking_address,
              staker,
              json_rpc_named_arguments
            )

          {pool_staking_address, result}
        end)

      error =
        Enum.find_value(pools_gas_estimates, fn {_, result} ->
          case result do
            {:error, reason} -> error_reason_to_string(reason)
            _ -> nil
          end
        end)

      pools =
        if error == nil do
          pools_gas_estimates = Map.new(pools_gas_estimates)

          Map.new(pools, fn {data, pool_staking_address} ->
            {:ok, estimate} = pools_gas_estimates[pool_staking_address]
            data = Map.put(data, :gas_estimate, estimate)
            {pool_staking_address, data}
          end)
        else
          %{}
        end

      {error, pools}
    end
  end

  def recalc_claim_reward(socket, staking_contract_address, epochs, pool_staking_address, staker) do
    :ets.insert(ContractState, {claim_reward_long_op_key(staker), true})

    try do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      amounts_result =
        ContractReader.call_get_reward_amount(
          staking_contract_address,
          epochs,
          pool_staking_address,
          staker,
          json_rpc_named_arguments
        )

      {error, amounts} =
        case amounts_result do
          {:ok, amounts} ->
            {nil, amounts}

          {:error, reason} ->
            {error_reason_to_string(reason), %{token_reward_sum: 0, native_reward_sum: 0}}
        end

      {error, gas_limit} =
        if error == nil do
          estimate_gas_result =
            ContractReader.claim_reward_estimate_gas(
              staking_contract_address,
              epochs,
              pool_staking_address,
              staker,
              json_rpc_named_arguments
            )

          case estimate_gas_result do
            {:ok, gas_limit} ->
              {nil, gas_limit}

            {:error, reason} ->
              {error_reason_to_string(reason), 0}
          end
        else
          {error, 0}
        end

      token = ContractState.get(:token)
      coin = get_coin()

      push(socket, "claim_reward_recalculations", %{
        token_reward_sum:
          StakesHelpers.format_token_amount(amounts.token_reward_sum, token,
            digits: token.decimals,
            ellipsize: false,
            symbol: false
          ),
        native_reward_sum:
          StakesHelpers.format_token_amount(amounts.native_reward_sum, coin,
            digits: coin.decimals,
            ellipsize: false,
            symbol: false
          ),
        gas_limit: gas_limit,
        error: error
      })
    after
      :ets.delete(ContractState, claim_reward_long_op_key(staker))
    end
  end

  defp claim_reward_long_op_active(socket) do
    if socket.assigns[@claim_reward_long_op] do
      true
    else
      staker = socket.assigns[:account]

      with [{_, true}] <- :ets.lookup(ContractState, claim_reward_long_op_key(staker)) do
        true
      end
    end
  end

  defp address_bytes_to_string(hash), do: "0x" <> Base.encode16(hash, case: :lower)

  defp array_to_ranges(numbers, prev_ranges \\ []) do
    length = Enum.count(numbers)

    if length > 0 do
      {first, last, next_index} = get_range(numbers)
      prev_ranges_reversed = Enum.reverse(prev_ranges)

      ranges =
        [{first, last} | prev_ranges_reversed]
        |> Enum.reverse()

      if next_index == 0 || next_index >= length do
        ranges
      else
        numbers
        |> Enum.slice(next_index, length - next_index)
        |> array_to_ranges(ranges)
      end
    else
      []
    end
  end

  defp error_reason_to_string(reason) do
    if is_map(reason) && Map.has_key?(reason, :message) && String.length(String.trim(reason.message)) > 0 do
      reason.message
    else
      gettext("JSON RPC error") <> ": " <> inspect(reason)
    end
  end

  defp get_range(numbers) do
    last_index =
      numbers
      |> Enum.with_index()
      |> Enum.find_index(fn {n, i} ->
        if i > 0, do: n != Enum.at(numbers, i - 1) + 1, else: false
      end)

    next_index = if last_index == nil, do: Enum.count(numbers), else: last_index
    first = Enum.at(numbers, 0)
    last = Enum.at(numbers, next_index - 1)
    {first, last, next_index}
  end

  defp push_contracts(socket) do
    if socket.assigns[:contracts_sent] do
      socket
    else
      token = ContractState.get(:token)

      push(socket, "contracts", %{
        staking_contract: ContractState.get(:staking_contract),
        block_reward_contract: ContractState.get(:block_reward_contract),
        validator_set_contract: ContractState.get(:validator_set_contract),
        token_decimals: to_string(token.decimals),
        token_symbol: token.symbol
      })

      assign(socket, :contracts_sent, true)
    end
  end

  defp claim_reward_long_op_key(staker) do
    staker = if staker == nil, do: "", else: staker
    Atom.to_string(@claim_reward_long_op) <> "_" <> staker
  end

  defp get_coin do
    %Token{symbol: Explorer.coin(), decimals: Decimal.new(18)}
  end

  defp handle_in_render_claim_reward_result(
         socket,
         data,
         staker,
         staking_contract_address,
         empty_staker,
         empty_staking_contract_address
       ) do
    cond do
      claim_reward_long_op_active(socket) == true ->
        {:reply, {:error, %{reason: gettext("Pools searching is already in progress for this address")}}, socket}

      empty_staker ->
        {:reply, {:error, %{reason: gettext("Unknown staker address. Please, choose your account in MetaMask")}},
         socket}

      empty_staking_contract_address ->
        {:reply, {:error, %{reason: gettext("Unknown address of Staking contract. Please, contact support")}}, socket}

      true ->
        result =
          if data["preload"] do
            %{
              html: View.render_to_string(StakesView, "_stakes_modal_claim_reward.html", %{}),
              socket: socket
            }
          else
            task = Task.async(__MODULE__, :find_claim_reward_pools, [socket, staker, staking_contract_address])

            %{
              html: "OK",
              socket: assign(socket, @claim_reward_long_op, %{task: task, staker: staker})
            }
          end

        {:reply, {:ok, %{html: result.html}}, result.socket}
    end
  end

  defp handle_in_recalc_claim_reward_result(
         socket,
         epochs,
         staking_contract_address,
         pool_staking_address,
         staker,
         empty_pool_staking_address,
         empty_staking_contract_address,
         empty_staker
       ) do
    cond do
      claim_reward_long_op_active(socket) == true ->
        {:reply, {:error, %{reason: gettext("Reward calculating is already in progress for this address")}}, socket}

      Enum.empty?(epochs) ->
        {:reply, {:error, %{reason: gettext("Staking epochs are not specified or not in the allowed range")}}, socket}

      empty_pool_staking_address ->
        {:reply, {:error, %{reason: gettext("Unknown pool staking address. Please, contact support")}}, socket}

      empty_staker ->
        {:reply, {:error, %{reason: gettext("Unknown staker address. Please, choose your account in MetaMask")}},
         socket}

      empty_staking_contract_address ->
        {:reply, {:error, %{reason: gettext("Unknown address of Staking contract. Please, contact support")}}, socket}

      true ->
        task =
          Task.async(__MODULE__, :recalc_claim_reward, [
            socket,
            staking_contract_address,
            epochs,
            pool_staking_address,
            staker
          ])

        socket = assign(socket, @claim_reward_long_op, %{task: task, staker: staker})
        {:reply, {:ok, %{html: "OK"}}, socket}
    end
  end
end
