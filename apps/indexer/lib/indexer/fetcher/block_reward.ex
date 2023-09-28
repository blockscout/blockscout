defmodule Indexer.Fetcher.BlockReward do
  @moduledoc """
  Fetches `t:Explorer.Chain.Block.Reward.t/0` for a given `t:Explorer.Chain.Block.block_number/0`.

  To protect from reorgs where the returned rewards are for same `number`, but a different `hash`, the `hash` is
  retrieved from the database and compared against that returned from `EthereumJSONRPC.`
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias Ecto.Changeset
  alias EthereumJSONRPC.FetchedBeneficiaries
  alias Explorer.Chain
  alias Explorer.Chain.{Block, Wei}
  alias Explorer.Chain.Cache.Accounts
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.BlockReward.Supervisor, as: BlockRewardSupervisor
  alias Indexer.Fetcher.{CoinBalance, CoinBalanceDailyUpdater}
  alias Indexer.Transform.{AddressCoinBalances, AddressCoinBalancesDaily, Addresses}

  @behaviour BufferedTask

  @default_max_batch_size 10
  @default_max_concurrency 4

  @doc """
  Asynchronously fetches block rewards for each `t:Explorer.Chain.Explorer.block_number/0`` in `block_numbers`.
  """
  @spec async_fetch([Block.block_number()]) :: :ok
  def async_fetch(block_numbers) when is_list(block_numbers) do
    if BlockRewardSupervisor.disabled?() do
      :ok
    else
      BufferedTask.buffer(__MODULE__, block_numbers)
    end
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_options =
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_options}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_blocks_without_rewards(
        initial,
        fn %{number: number}, acc ->
          reducer.(number, acc)
        end
      )

    final
  end

  @impl BufferedTask
  @decorate trace(name: "fetch", resource: "Indexer.Fetcher.BlockReward.run/2", service: :indexer, tracer: Tracer)
  def run(entries, json_rpc_named_arguments) do
    hash_string_by_number =
      entries
      |> Enum.uniq()
      |> hash_string_by_number()

    consensus_numbers = Map.keys(hash_string_by_number)

    consensus_number_count = Enum.count(consensus_numbers)

    Logger.metadata(count: consensus_number_count)

    Logger.debug(fn -> "fetching" end)

    consensus_numbers
    |> EthereumJSONRPC.fetch_beneficiaries(json_rpc_named_arguments)
    |> case do
      {:ok, fetched_beneficiaries} ->
        run_fetched_beneficiaries(fetched_beneficiaries, hash_string_by_number)

      :ignore ->
        :ok

      {:error, reason} ->
        Logger.error(
          fn ->
            ["failed to fetch: ", inspect(reason), " hash: ", inspect(hash_string_by_number)]
          end,
          error_count: consensus_number_count
        )

        {:retry, consensus_numbers}
    end
  end

  defp hash_string_by_number(numbers) when is_list(numbers) do
    numbers
    |> Chain.block_hash_by_number()
    |> Enum.into(%{}, fn {number, hash} ->
      {number, to_string(hash)}
    end)
  end

  defp run_fetched_beneficiaries(%FetchedBeneficiaries{params_set: params_set, errors: errors}, hash_string_by_number) do
    params_set
    |> filter_consensus_params(hash_string_by_number)
    |> case do
      [] ->
        retry_errors(errors)

      beneficiaries_params ->
        beneficiaries_params
        |> add_gas_payments()
        |> add_timestamp()
        |> import_block_reward_params()
        |> case do
          {:ok, %{address_coin_balances: address_coin_balances, addresses: addresses}} ->
            Accounts.drop(addresses)

            CoinBalance.async_fetch_balances(address_coin_balances)

            retry_errors(errors)

          {:error, [%Changeset{} | _] = changesets} ->
            Logger.error(fn -> ["Failed to validate: ", inspect(changesets)] end,
              error_count: Enum.count(hash_string_by_number)
            )

            retry_beneficiaries_params(beneficiaries_params)

          {:error, step, failed_value, _changes_so_far} ->
            Logger.error(fn -> ["Failed to import", inspect(failed_value)] end,
              step: step,
              error_count: Enum.count(hash_string_by_number)
            )

            retry_beneficiaries_params(beneficiaries_params)
        end
    end
  end

  defp filter_consensus_params(params_set, hash_string_by_number) do
    Enum.filter(params_set, fn %{block_number: block_number, block_hash: block_hash} ->
      case Map.fetch!(hash_string_by_number, block_number) do
        ^block_hash ->
          true

        other_block_hash ->
          Logger.debug(fn ->
            [
              "fetch beneficiaries reported block number (",
              to_string(block_number),
              ") maps to different (",
              other_block_hash,
              ") block hash than the one in the database (",
              block_hash,
              ").  A reorg has occurred."
            ]
          end)

          false
      end
    end)
  end

  defp add_gas_payments(beneficiaries_params) do
    beneficiaries_params
    |> add_validator_rewards()
    |> reduce_uncle_rewards()
  end

  def add_timestamp(beneficiaries_params) do
    timestamp_by_block_hash =
      beneficiaries_params
      |> Enum.map(& &1.block_hash)
      |> Chain.timestamp_by_block_hash()

    Enum.map(beneficiaries_params, fn %{block_hash: block_hash_str} = beneficiary ->
      {:ok, block_hash} = Chain.string_to_block_hash(block_hash_str)

      case timestamp_by_block_hash do
        %{^block_hash => block_timestamp} ->
          Map.put(beneficiary, :block_timestamp, block_timestamp)

        _ ->
          beneficiary
      end
    end)
  end

  defp add_validator_rewards(beneficiaries_params) do
    gas_payment_by_block_hash =
      beneficiaries_params
      |> Stream.filter(&(&1.address_type == :validator))
      |> Enum.map(& &1.block_hash)
      |> Chain.gas_payment_by_block_hash()

    Enum.map(beneficiaries_params, fn %{block_hash: block_hash, address_type: address_type} = beneficiary ->
      if address_type == :validator do
        beneficiary_with_reward(gas_payment_by_block_hash, block_hash, beneficiary)
      else
        beneficiary
      end
    end)
  end

  defp beneficiary_with_reward(gas_payment_by_block_hash, block_hash, beneficiary) do
    case gas_payment_by_block_hash do
      %{^block_hash => gas_payment} ->
        {:ok, minted} = Wei.cast(beneficiary.reward)
        %{beneficiary | reward: Wei.sum(minted, gas_payment)}

      _ ->
        beneficiary
    end
  end

  def reduce_uncle_rewards(beneficiaries_params) do
    beneficiaries_params
    |> Enum.reduce([], fn %{address_type: address_type} = beneficiary, acc ->
      current =
        if address_type == :uncle do
          reward = get_reward(beneficiaries_params, beneficiary)

          %{beneficiary | reward: reward}
        else
          beneficiary
        end

      [current | acc]
    end)
    |> Enum.uniq()
  end

  defp get_reward(beneficiaries_params, beneficiary) do
    Enum.reduce(beneficiaries_params, %Wei{value: 0}, fn %{
                                                           address_type: address_type,
                                                           address_hash: address_hash,
                                                           block_hash: block_hash
                                                         } = current_beneficiary,
                                                         reward_acc ->
      reduce_uncle_rewards_inner(reward_acc, beneficiary, address_type, address_hash, block_hash, current_beneficiary)
    end)
  end

  defp reduce_uncle_rewards_inner(reward_acc, beneficiary, address_type, address_hash, block_hash, current_beneficiary) do
    if address_type == beneficiary.address_type && address_hash == beneficiary.address_hash &&
         block_hash == beneficiary.block_hash do
      {:ok, minted} = Wei.cast(current_beneficiary.reward)

      Wei.sum(reward_acc, minted)
    else
      reward_acc
    end
  end

  defp import_block_reward_params(block_rewards_params) when is_list(block_rewards_params) do
    addresses_params = Addresses.extract_addresses(%{block_reward_contract_beneficiaries: block_rewards_params})
    address_coin_balances_params_set = AddressCoinBalances.params_set(%{beneficiary_params: block_rewards_params})

    address_coin_balances_params_with_block_timestamp =
      block_rewards_params
      |> Enum.map(fn block_rewards_param ->
        %{
          address_hash: block_rewards_param.address_hash,
          block_number: block_rewards_param.block_number,
          block_timestamp: block_rewards_param.block_timestamp
        }
      end)
      |> Enum.into(MapSet.new())

    address_coin_balances_params_with_block_timestamp_set = %{
      address_coin_balances_params_with_block_timestamp: address_coin_balances_params_with_block_timestamp
    }

    address_coin_balances_daily_params_set =
      AddressCoinBalancesDaily.params_set(address_coin_balances_params_with_block_timestamp_set)

    CoinBalanceDailyUpdater.add_daily_balances_params(address_coin_balances_daily_params_set)

    Chain.import(%{
      addresses: %{params: addresses_params},
      address_coin_balances: %{params: address_coin_balances_params_set},
      block_rewards: %{params: block_rewards_params}
    })
  end

  defp retry_beneficiaries_params(beneficiaries_params) when is_list(beneficiaries_params) do
    entries = Enum.map(beneficiaries_params, & &1.block_number)

    {:retry, entries}
  end

  defp retry_errors([]), do: :ok

  defp retry_errors(errors) when is_list(errors) do
    retried_entries = fetched_beneficiaries_errors_to_entries(errors)

    Logger.error(
      fn ->
        [
          "failed to fetch: ",
          fetched_beneficiaries_errors_to_iodata(errors)
        ]
      end,
      error_count: Enum.count(retried_entries)
    )

    {:retry, retried_entries}
  end

  defp fetched_beneficiaries_errors_to_entries(errors) when is_list(errors) do
    Enum.map(errors, &fetched_beneficiary_error_to_entry/1)
  end

  defp fetched_beneficiary_error_to_entry(%{data: %{block_quantity: block_quantity}}) when is_binary(block_quantity) do
    quantity_to_integer(block_quantity)
  end

  defp fetched_beneficiaries_errors_to_iodata(errors) when is_list(errors) do
    fetched_beneficiaries_errors_to_iodata(errors, [])
  end

  defp fetched_beneficiaries_errors_to_iodata([], iodata), do: iodata

  defp fetched_beneficiaries_errors_to_iodata([error | errors], iodata) do
    fetched_beneficiaries_errors_to_iodata(errors, [iodata | fetched_beneficiary_error_to_iodata(error)])
  end

  defp fetched_beneficiary_error_to_iodata(%{code: code, message: message, data: %{block_quantity: block_quantity}})
       when is_integer(code) and is_binary(message) and is_binary(block_quantity) do
    ["@", quantity_to_integer(block_quantity), ": (", to_string(code), ") ", message, ?\n]
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(3),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: Indexer.Fetcher.BlockReward.TaskSupervisor,
      metadata: [fetcher: :block_reward]
    ]
  end
end
