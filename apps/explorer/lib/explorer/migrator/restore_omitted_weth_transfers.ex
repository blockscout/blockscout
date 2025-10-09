defmodule Explorer.Migrator.RestoreOmittedWETHTransfers do
  @moduledoc """
  Inserts missed WETH token transfers
  """

  use GenServer, restart: :transient

  alias Explorer.{Chain, Helper}
  alias Explorer.Chain.{Log, Token, TokenTransfer}
  alias Explorer.Migrator.MigrationStatus

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  require Logger

  @enqueue_busy_waiting_timeout 500
  @migration_timeout 250
  @migration_name "restore_omitted_weth_transfers"

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :check_env}}
  end

  @impl true
  def handle_continue(:check_env, state) do
    list = Application.get_env(:explorer, Explorer.Chain.TokenTransfer)[:whitelisted_weth_contracts]

    cond do
      Enum.empty?(list) ->
        {:stop, :normal, state}

      check_token_types(list) ->
        {:noreply, %{}, {:continue, :check_migration_status}}

      true ->
        Logger.error("Stopping")
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_continue(:check_migration_status, state) do
    case MigrationStatus.get_status(@migration_name) do
      "completed" ->
        {:stop, :normal, state}

      _ ->
        MigrationStatus.set_status(@migration_name, "started")
        {:noreply, %{}, {:continue, :ok}}
    end
  end

  @impl true
  def handle_continue(:ok, _state) do
    %{ref: ref} =
      Task.async(fn ->
        Log.stream_unfetched_weth_token_transfers(&enqueue_if_queue_is_not_full/1)
      end)

    to_insert =
      Application.get_env(:explorer, Explorer.Chain.TokenTransfer)[:whitelisted_weth_contracts]
      |> Enum.map(fn contract_address_hash_string ->
        if !Token.by_contract_address_hash_exists?(contract_address_hash_string, []) do
          %{
            contract_address_hash: contract_address_hash_string,
            type: "ERC-20"
          }
        end
      end)
      |> Enum.reject(&is_nil/1)

    if !Enum.empty?(to_insert) do
      Chain.import(%{tokens: %{params: to_insert}})
    end

    Process.send_after(self(), :migrate, @migration_timeout)

    {:noreply, %{queue: [], current_concurrency: 0, stream_ref: ref, stream_is_over: false}}
  end

  defp enqueue_if_queue_is_not_full(log) do
    if GenServer.call(__MODULE__, :not_full?) do
      GenServer.cast(__MODULE__, {:append_to_queue, log})
    else
      :timer.sleep(@enqueue_busy_waiting_timeout)

      enqueue_if_queue_is_not_full(log)
    end
  end

  @impl true
  def handle_call(:not_full?, _from, %{queue: queue} = state) do
    {:reply, Enum.count(queue) < max_queue_size(), state}
  end

  @impl true
  def handle_cast({:append_to_queue, log}, %{queue: queue} = state) do
    {:noreply, %{state | queue: [log | queue]}}
  end

  @impl true
  def handle_info(:migrate, %{queue: [], stream_is_over: true, current_concurrency: current_concurrency} = state) do
    if current_concurrency > 0 do
      {:noreply, state}
    else
      Logger.info("RestoreOmittedWETHTransfers migration is complete.")

      MigrationStatus.set_status(@migration_name, "completed")
      {:stop, :normal, state}
    end
  end

  # fetch token balances
  @impl true
  def handle_info(:migrate, %{queue: queue, current_concurrency: current_concurrency} = state) do
    if Enum.count(queue) > 0 and current_concurrency < concurrency() do
      to_take = batch_size() * (concurrency() - current_concurrency)
      {to_process, remainder} = Enum.split(queue, to_take)

      spawned_tasks =
        to_process
        |> Enum.chunk_every(batch_size())
        |> Enum.map(fn batch ->
          run_task(batch)
        end)

      if Enum.empty?(remainder) do
        Process.send_after(self(), :migrate, migration_timeout())
      else
        Process.send(self(), :migrate, [])
      end

      {:noreply, %{state | queue: remainder, current_concurrency: current_concurrency + Enum.count(spawned_tasks)}}
    else
      Process.send_after(self(), :migrate, migration_timeout())
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({ref, _answer}, %{stream_ref: ref} = state) do
    {:noreply, %{state | stream_is_over: true}}
  end

  @impl true
  def handle_info({ref, _answer}, %{current_concurrency: counter} = state) do
    Process.demonitor(ref, [:flush])
    Process.send(self(), :migrate, [])
    {:noreply, %{state | current_concurrency: counter - 1}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{stream_ref: ref} = state) do
    {:noreply, %{state | stream_is_over: true}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{current_concurrency: counter} = state) do
    Process.send(self(), :migrate, [])
    {:noreply, %{state | current_concurrency: counter - 1}}
  end

  defp migrate_batch(batch) do
    {token_transfers, token_balances} =
      batch
      |> Enum.map(fn log ->
        with %{second_topic: second_topic, third_topic: nil, fourth_topic: nil, data: data}
             when not is_nil(second_topic) <-
               log,
             [amount] <- Helper.decode_data(data, [{:uint, 256}]) do
          {from_address_hash, to_address_hash, balance_address_hash} =
            if log.first_topic == TokenTransfer.weth_deposit_signature() do
              to_address_hash = Helper.truncate_address_hash(to_string(second_topic))
              {burn_address_hash_string(), to_address_hash, to_address_hash}
            else
              from_address_hash = Helper.truncate_address_hash(to_string(second_topic))
              {from_address_hash, burn_address_hash_string(), from_address_hash}
            end

          token_transfer = %{
            amount: Decimal.new(amount || 0),
            block_number: log.block_number,
            block_hash: log.block_hash,
            log_index: log.index,
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash,
            token_contract_address_hash: log.address_hash,
            transaction_hash: log.transaction_hash,
            token_ids: nil,
            token_type: "ERC-20"
          }

          token_balance = %{
            address_hash: balance_address_hash,
            token_contract_address_hash: log.address_hash,
            block_number: log.block_number,
            token_id: nil,
            token_type: "ERC-20"
          }

          {token_transfer, token_balance}
        else
          _ ->
            Logger.error(
              "Failed to decode log: (transaction_hash, block_hash, index) = #{to_string(log.transaction_hash)},  #{to_string(log.block_hash)}, #{to_string(log.index)}"
            )

            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.unzip()

    current_token_balances =
      token_balances
      |> Enum.group_by(fn %{
                            address_hash: address_hash,
                            token_contract_address_hash: token_contract_address_hash
                          } ->
        {address_hash, token_contract_address_hash}
      end)
      |> Enum.map(fn {_, grouped_address_token_balances} ->
        Enum.max_by(grouped_address_token_balances, fn %{block_number: block_number} -> block_number end)
      end)
      |> Enum.sort_by(&{&1.token_contract_address_hash, &1.address_hash})

    if !Enum.empty?(token_transfers) do
      Chain.import(%{
        token_transfers: %{params: token_transfers},
        address_token_balances: %{params: token_balances},
        address_current_token_balances: %{
          params: current_token_balances
        }
      })
    end
  end

  defp run_task(batch) do
    Task.Supervisor.async_nolink(Explorer.WETHMigratorSupervisor, fn ->
      migrate_batch(batch)
    end)
  end

  defp check_token_types(token_address_hashes) do
    token_address_hashes
    |> Chain.get_token_types()
    |> Enum.reduce(true, fn {token_hash, token_type}, acc ->
      if token_type == "ERC-20" do
        acc
      else
        Logger.error("Wrong token type of #{to_string(token_hash)}: #{token_type}")
        false
      end
    end)
  end

  def concurrency, do: Application.get_env(:explorer, __MODULE__)[:concurrency]

  def batch_size, do: Application.get_env(:explorer, __MODULE__)[:batch_size]

  def migration_timeout, do: Application.get_env(:explorer, __MODULE__)[:timeout]

  def max_queue_size, do: concurrency() * batch_size() * 2
end
