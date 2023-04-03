defmodule Indexer.Block.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges.
  """

  use Spandex.Decorators

  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias EthereumJSONRPC.{Blocks, FetchedBeneficiaries}
  alias Explorer.Celo.ContractEvents.{EventMap, EventTransformer}
  alias Explorer.Celo.ContractEvents.Registry.RegistryUpdatedEvent
  alias Explorer.Celo.{AddressCache, CoreContracts}
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{Address, Block, Hash, Import, Transaction, Wei}
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.Cache.Blocks, as: BlocksCache
  alias Explorer.Chain.Cache.{Accounts, BlockNumber, Transactions, Uncles}
  alias Indexer.Block.Fetcher.Receipts

  alias Explorer.Celo.Util

  alias Indexer.Fetcher.{
    BlockReward,
    CeloAccount,
    CeloValidator,
    CeloValidatorGroup,
    CeloValidatorHistory,
    CeloVoters,
    CoinBalance,
    ContractCode,
    EventProcessor,
    InternalTransaction,
    ReplacedTransaction,
    Token,
    TokenBalance,
    TokenInstance,
    UncleBlock
  }

  alias Indexer.Tracer

  alias Indexer.Transform.{
    AddressCoinBalances,
    AddressCoinBalancesDaily,
    Addresses,
    AddressTokenBalances,
    CeloAccounts,
    MintTransfers,
    TokenTransfers
  }

  alias Indexer.Transform.Blocks, as: TransformBlocks

  @type address_hash_to_fetched_balance_block_number :: %{String.t() => Block.block_number()}

  @type t :: %__MODULE__{}

  @doc """
  Calculates the balances and internal transactions and imports those with the given data.
  """
  @callback import(
              t,
              %{
                address_hash_to_fetched_balance_block_number: address_hash_to_fetched_balance_block_number,
                addresses: Import.Runner.options(),
                address_coin_balances: Import.Runner.options(),
                address_coin_balances_daily: Import.Runner.options(),
                address_token_balances: Import.Runner.options(),
                blocks: Import.Runner.options(),
                block_second_degree_relations: Import.Runner.options(),
                block_rewards: Import.Runner.options(),
                broadcast: term(),
                logs: Import.Runner.options(),
                token_transfers: Import.Runner.options(),
                tokens: Import.Runner.options(),
                transactions: Import.Runner.options(),
                celo_accounts: Import.Runner.options()
              }
            ) :: Import.all_result()

  # These are all the *default* values for options.
  # DO NOT use them directly in the code.  Get options from `state`.

  @receipts_batch_size 250
  @receipts_concurrency 10

  @doc false
  def default_receipts_batch_size, do: @receipts_batch_size

  @doc false
  def default_receipts_concurrency, do: @receipts_concurrency

  @enforce_keys ~w(json_rpc_named_arguments)a
  defstruct broadcast: nil,
            callback_module: nil,
            json_rpc_named_arguments: nil,
            receipts_batch_size: @receipts_batch_size,
            receipts_concurrency: @receipts_concurrency

  @doc """
  Required named arguments

    * `:json_rpc_named_arguments` - `t:EthereumJSONRPC.json_rpc_named_arguments/0` passed to
        `EthereumJSONRPC.json_rpc/2`.

  The follow options can be overridden:

    * `:receipts_batch_size` - The number of receipts to request in one call to the JSONRPC.  Defaults to
      `#{@receipts_batch_size}`.  Receipt requests also include the logs for when the transaction was collated into the
      block.  *These logs are not paginated.*
    * `:receipts_concurrency` - The number of concurrent requests of `:receipts_batch_size` to allow against the JSONRPC
      **for each block range**.  Defaults to `#{@receipts_concurrency}`.  *Each transaction only has one receipt.*

  """
  def new(named_arguments) when is_map(named_arguments) do
    struct!(__MODULE__, named_arguments)
  end

  defp process_extra_logs(extra_logs) do
    e_logs =
      extra_logs
      |> Enum.filter(fn %{transaction_hash: tx_hash, block_hash: block_hash} ->
        tx_hash == block_hash
      end)
      |> Enum.map(fn log ->
        Map.put(log, :transaction_hash, nil)
      end)

    e_logs
  end

  # If a RegistryUpdated event was sent from the registry contract it is treated as a new core contract, inserted into
  # the database and used to update the contract cache.
  defp process_celo_core_contracts(logs) do
    logs
    |> Enum.filter(fn log ->
      log.first_topic == RegistryUpdatedEvent.topic() and log.address_hash == CoreContracts.registry_address()
    end)
    |> Enum.map(fn registry_updated_log ->
      event =
        %RegistryUpdatedEvent{}
        |> EventTransformer.from_params(registry_updated_log)

      {:ok, new_contract_address} = event.addr |> Explorer.Chain.Hash.Address.cast()

      %{
        name: event.identifier,
        address_hash: new_contract_address,
        block_number: event.__block_number,
        log_index: event.__log_index
      }
    end)
    |> tap(fn new_contracts ->
      Enum.each(new_contracts, fn %{name: name, address_hash: address} ->
        Logger.info(
          "New celo core contract discovered: #{name} at address #{to_string(address)}, cache will be updated"
        )

        AddressCache.update_cache(name, to_string(address))
      end)
    end)
  end

  @decorate span(tracer: Tracer)
  @spec fetch_and_import_range(t, Range.t()) ::
          {:ok, %{inserted: %{}, errors: [EthereumJSONRPC.Transport.error()]}}
          | {:error,
             {step :: atom(), reason :: [Ecto.Changeset.t()] | term()}
             | {step :: atom(), failed_value :: term(), changes_so_far :: term()}}
  def fetch_and_import_range(
        %__MODULE__{
          broadcast: _broadcast,
          callback_module: callback_module,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state,
        _..last_block = range
      )
      when callback_module != nil do
    with {:blocks,
          {
            :ok,
            # Fetch blocks and associated block data (transactions included)
            %Blocks{
              blocks_params: blocks_params,
              transactions_params: transactions_params_without_receipts,
              block_second_degree_relations_params: block_second_degree_relations_params,
              errors: blocks_errors
            }
          }} <- {:blocks, EthereumJSONRPC.fetch_blocks_by_range(range, json_rpc_named_arguments)},
         blocks = TransformBlocks.transform_blocks(blocks_params),

         # Fetch and process logs + tx receipts
         {:logs, {:ok, %{logs: epoch_logs}}} <- {:logs, EthereumJSONRPC.fetch_logs(range, json_rpc_named_arguments)},
         {:receipts, {:ok, receipt_params}} <- {:receipts, Receipts.fetch(state, transactions_params_without_receipts)},
         %{logs: tx_logs, receipts: receipts} = receipt_params,
         logs = tx_logs ++ process_extra_logs(epoch_logs),

         # combine transactions with receipts
         transactions_with_receipts = Receipts.put(transactions_params_without_receipts, receipts),

         # extract token transfers from logs
         %{token_transfers: normal_token_transfers, tokens: normal_tokens} = TokenTransfers.parse(logs),

         # extract celo core contract events from logs
         new_core_contracts = process_celo_core_contracts(logs),
         celo_contract_events = EventMap.celo_rpc_to_event_params(logs),

         # Get required core contract addresses from the registry
         {:ok, celo_token} = Util.get_address("GoldToken"),
         {:ok, stable_token_usd} = Util.get_address("StableToken"),
         {:ok, oracle_address} = Util.get_address("SortedOracles"),

         # Create CELO token transfers from native tx values
         %{token_transfers: native_celo_token_transfers} =
           TokenTransfers.parse_tx(transactions_with_receipts, celo_token),

         # extract various celo protocol data from logs + oracles
         %{
           accounts: celo_accounts,
           validators: celo_validators,
           validator_groups: celo_validator_groups,
           voters: celo_voters,
           signers: signers,
           attestations_fulfilled: attestations_fulfilled,
           attestations_requested: attestations_requested,
           exchange_rates: exchange_rates,
           account_names: account_names,
           wallets: celo_wallets,
           withdrawals: celo_withdrawals,
           unlocked: celo_unlocked
         } = CeloAccounts.parse(logs, oracle_address),

         # extract cusd + CELO exchange rates from above
         market_history =
           exchange_rates
           |> Enum.filter(fn el ->
             el.token == stable_token_usd && el.rate > 0
           end)
           |> Enum.map(fn %{rate: rate, stamp: time} ->
             inv_rate = Decimal.from_float(1 / rate)
             date = DateTime.to_date(DateTime.from_unix!(time))
             %{opening_price: inv_rate, closing_price: inv_rate, date: date}
           end),
         exchange_rates =
           (if Enum.count(exchange_rates) > 0 and celo_token != nil do
              [%{token: celo_token, rate: 1.0} | exchange_rates]
            else
              []
            end),

         # extract token minting transfers (bridged)
         %{mint_transfers: mint_transfers} = MintTransfers.parse(logs),

         # fetch block reward beneficiaries
         %FetchedBeneficiaries{params_set: beneficiary_params_set, errors: beneficiaries_errors} =
           fetch_beneficiaries(blocks, transactions_with_receipts, json_rpc_named_arguments),

         # fold celo transfers into list of token transfers (treat native chain asset as erc-20)
         tokens = [%{contract_address_hash: celo_token, type: "ERC-20"} | normal_tokens],
         token_transfers = normal_token_transfers ++ native_celo_token_transfers,

         # extract all referenced addresses from data
         addresses =
           Addresses.extract_addresses(%{
             block_reward_contract_beneficiaries: MapSet.to_list(beneficiary_params_set),
             blocks: blocks,
             logs: logs,
             mint_transfers: mint_transfers,
             token_transfers: token_transfers,
             transactions: transactions_with_receipts,
             wallets: celo_wallets,
             # The address of the CELO token has to be added to the addresses table
             celo_token: [%{hash: celo_token, block_number: last_block}]
           }),

         # get celo transfers (erc-20)
         celo_transfers =
           normal_token_transfers
           |> Enum.filter(fn %{token_contract_address_hash: contract} -> contract == celo_token end),

         # extract (instant) coin balances from above data
         coin_balances_params_set =
           %{
             beneficiary_params: MapSet.to_list(beneficiary_params_set),
             blocks_params: blocks,
             logs_params: logs,
             celo_transfers: celo_transfers,
             transactions_params: transactions_with_receipts
           }
           |> AddressCoinBalances.params_set(),

         # extract daily coin balance from above instant balances
         coin_balances_params_daily_set =
           %{
             coin_balances_params: coin_balances_params_set,
             blocks: blocks
           }
           |> AddressCoinBalancesDaily.params_set(),

         # calculate gas payment beneficiaries
         # extract address token balances from token transfers
         beneficiaries_with_gas_payment =
           beneficiaries_with_gas_payment(blocks, beneficiary_params_set, transactions_with_receipts),
         address_token_balances = AddressTokenBalances.params_set(%{token_transfers_params: token_transfers}),
         {:ok, inserted} <-
           __MODULE__.import(
             state,
             %{
               addresses: %{params: addresses},
               address_coin_balances: %{params: coin_balances_params_set},
               address_coin_balances_daily: %{params: coin_balances_params_daily_set},
               address_token_balances: %{params: address_token_balances},
               blocks: %{params: blocks},
               block_second_degree_relations: %{params: block_second_degree_relations_params},
               block_rewards: %{errors: beneficiaries_errors, params: beneficiaries_with_gas_payment},
               logs: %{params: logs},
               account_names: %{params: account_names},
               celo_signers: %{params: signers},
               celo_contract_events: %{params: celo_contract_events},
               celo_core_contracts: %{params: new_core_contracts},
               token_transfers: %{params: token_transfers},
               tokens: %{params: tokens, on_conflict: :nothing},
               transactions: %{params: transactions_with_receipts},
               exchange_rate: %{params: exchange_rates},
               wallets: %{params: celo_wallets}
             }
           ) do
      result = {:ok, %{inserted: inserted, errors: blocks_errors}}

      accounts = Enum.uniq(celo_accounts ++ attestations_fulfilled ++ attestations_requested)

      async_import_celo_accounts(%{
        celo_accounts: %{params: accounts, requested: attestations_requested, fulfilled: attestations_fulfilled}
      })

      Market.bulk_insert_history(market_history)

      async_import_celo_validators(%{celo_validators: %{params: celo_validators}})
      async_import_celo_validator_groups(%{celo_validator_groups: %{params: celo_validator_groups}})
      async_import_celo_voters(%{celo_voters: %{params: celo_voters}})
      async_import_celo_validator_history(range)

      insert_celo_unlocked(celo_unlocked)
      delete_celo_unlocked(celo_withdrawals)
      update_block_cache(inserted[:blocks])
      update_transactions_cache(inserted[:transactions])
      update_addresses_cache(inserted[:addresses])
      update_uncles_cache(inserted[:block_second_degree_relations])

      process_events(inserted[:logs])

      result
    else
      {step, {:error, reason}} ->
        {:error, {step, reason}}

      {step, :error} ->
        {:error, {step, "Unknown error"}}

      {:import, {:error, step, failed_value, changes_so_far}} ->
        {:error, {step, failed_value, changes_so_far}}
    end
  end

  defp process_events([]), do: :ok
  defp process_events(events), do: EventProcessor.enqueue_logs(events)

  defp update_block_cache([]), do: :ok

  defp update_block_cache(blocks) when is_list(blocks) do
    {min_block, max_block} = Enum.min_max_by(blocks, & &1.number)

    BlockNumber.update_all(max_block.number)
    BlockNumber.update_all(min_block.number)
    BlocksCache.update(blocks)
  end

  defp update_block_cache(_), do: :ok

  defp update_transactions_cache(transactions) do
    Transactions.update(transactions)
  end

  defp update_addresses_cache(addresses), do: Accounts.drop(addresses)

  defp update_uncles_cache(updated_relations) do
    Uncles.update_from_second_degree_relations(updated_relations)
  end

  defp delete_celo_unlocked(withdrawals) do
    case withdrawals do
      [[]] ->
        0

      withdrawals ->
        Enum.each(withdrawals, fn %{address: address, amount: amount} -> Chain.delete_celo_unlocked(address, amount) end)
    end
  end

  defp insert_celo_unlocked(unlocked) do
    case unlocked do
      [[]] ->
        0

      unlocked ->
        Enum.each(unlocked, fn %{address: address, amount: amount, available: available} ->
          Chain.insert_celo_unlocked(address, amount, available)
        end)
    end
  end

  def import(
        %__MODULE__{broadcast: broadcast, callback_module: callback_module} = state,
        options
      )
      when is_map(options) do
    {address_hash_to_fetched_balance_block_number, import_options} =
      pop_address_hash_to_fetched_balance_block_number(options)

    options_with_broadcast =
      Map.merge(
        import_options,
        %{
          address_hash_to_fetched_balance_block_number: address_hash_to_fetched_balance_block_number,
          broadcast: broadcast
        }
      )

    callback_module.import(state, options_with_broadcast)
  end

  def async_import_token_instances(%{token_transfers: token_transfers}) do
    TokenInstance.async_fetch(token_transfers)
  end

  def async_import_token_instances(_), do: :ok

  def async_import_block_rewards([]), do: :ok

  def async_import_block_rewards(errors) when is_list(errors) do
    errors
    |> block_reward_errors_to_block_numbers()
    |> BlockReward.async_fetch()
  end

  def async_import_coin_balances(%{addresses: addresses}, %{
        address_hash_to_fetched_balance_block_number: address_hash_to_block_number
      }) do
    addresses
    |> Enum.map(fn %Address{hash: address_hash} ->
      block_number = Map.fetch!(address_hash_to_block_number, to_string(address_hash))
      %{address_hash: address_hash, block_number: block_number}
    end)
    |> CoinBalance.async_fetch_balances()
  end

  def async_import_coin_balances(_, _), do: :ok

  def async_import_created_contract_codes(%{transactions: transactions}) do
    transactions
    |> Enum.flat_map(fn
      %Transaction{
        block_number: block_number,
        hash: hash,
        created_contract_address_hash: %Hash{} = created_contract_address_hash,
        created_contract_code_indexed_at: nil
      } ->
        [%{block_number: block_number, hash: hash, created_contract_address_hash: created_contract_address_hash}]

      %Transaction{created_contract_address_hash: nil} ->
        []
    end)
    |> ContractCode.async_fetch(10_000)
  end

  def async_import_created_contract_codes(_), do: :ok

  def async_import_internal_transactions(%{blocks: blocks}) do
    blocks
    |> Enum.map(fn %Block{number: block_number} -> block_number end)
    |> InternalTransaction.async_fetch(10_000)
  end

  def async_import_internal_transactions(_), do: :ok

  def async_import_tokens(%{tokens: tokens}) do
    tokens
    |> Enum.map(& &1.contract_address_hash)
    |> Token.async_fetch()
  end

  def async_import_tokens(_), do: :ok

  def async_import_token_balances(%{address_token_balances: token_balances}) do
    TokenBalance.async_fetch(token_balances)
  end

  def async_import_token_balances(_), do: :ok

  def async_import_celo_accounts(%{celo_accounts: accounts}) do
    CeloAccount.async_fetch(accounts)
  end

  def async_import_celo_accounts(_), do: :ok

  def async_import_celo_validators(%{celo_validators: accounts}) do
    CeloValidator.async_fetch(accounts)
  end

  def async_import_celo_validators(_), do: :ok

  def async_import_celo_validator_history(range) do
    CeloValidatorHistory.async_fetch(range)
  end

  def async_import_celo_validator_groups(%{celo_validator_groups: accounts}) do
    CeloValidatorGroup.async_fetch(accounts)
  end

  def async_import_celo_validator_groups(_), do: :ok

  def async_import_celo_voters(%{celo_voters: accounts}) do
    CeloVoters.async_fetch(accounts)
  end

  def async_import_celo_voters(_), do: :ok

  def async_import_uncles(%{block_second_degree_relations: block_second_degree_relations}) do
    UncleBlock.async_fetch_blocks(block_second_degree_relations)
  end

  def async_import_uncles(_), do: :ok

  def async_import_replaced_transactions(%{transactions: transactions}) do
    transactions
    |> Enum.flat_map(fn
      %Transaction{block_hash: %Hash{} = block_hash, nonce: nonce, from_address_hash: %Hash{} = from_address_hash} ->
        [%{block_hash: block_hash, nonce: nonce, from_address_hash: from_address_hash}]

      %Transaction{block_hash: nil} ->
        []
    end)
    |> ReplacedTransaction.async_fetch(10_000)
  end

  def async_import_replaced_transactions(_), do: :ok

  defp block_reward_errors_to_block_numbers(block_reward_errors) when is_list(block_reward_errors) do
    Enum.map(block_reward_errors, &block_reward_error_to_block_number/1)
  end

  defp block_reward_error_to_block_number(%{data: %{block_number: block_number}}) when is_integer(block_number) do
    block_number
  end

  defp block_reward_error_to_block_number(%{data: %{block_quantity: block_quantity}}) when is_binary(block_quantity) do
    quantity_to_integer(block_quantity)
  end

  defp fetch_beneficiaries(blocks, all_transactions, json_rpc_named_arguments) do
    case Application.get_env(:indexer, :fetch_rewards_way) do
      "manual" -> fetch_beneficiaries_manual(blocks, all_transactions)
      _ -> fetch_beneficiaries_by_trace_block(blocks, json_rpc_named_arguments)
    end
  end

  def fetch_beneficiaries_manual(blocks, all_transactions) when is_list(blocks) do
    block_transactions_map = Enum.group_by(all_transactions, & &1.block_number)

    blocks
    |> Enum.map(fn block -> fetch_beneficiaries_manual(block, block_transactions_map[block.number] || []) end)
    |> Enum.reduce(%FetchedBeneficiaries{}, fn params_set, %{params_set: acc_params_set} = acc ->
      %FetchedBeneficiaries{acc | params_set: MapSet.union(acc_params_set, params_set)}
    end)
  end

  def fetch_beneficiaries_manual(block, transactions) do
    block
    |> Chain.block_reward_by_parts(transactions)
    |> reward_parts_to_beneficiaries()
  end

  defp reward_parts_to_beneficiaries(reward_parts) do
    reward =
      reward_parts.static_reward
      |> Wei.sum(reward_parts.txn_fees)
      |> Wei.sub(reward_parts.burned_fees)
      |> Wei.sum(reward_parts.uncle_reward)

    MapSet.new([
      %{
        address_hash: reward_parts.miner_hash,
        block_hash: reward_parts.block_hash,
        block_number: reward_parts.block_number,
        reward: reward,
        address_type: :validator
      }
    ])
  end

  defp fetch_beneficiaries_by_trace_block(blocks, json_rpc_named_arguments) do
    hash_string_by_number =
      Enum.into(blocks, %{}, fn %{number: number, hash: hash_string}
                                when is_integer(number) and is_binary(hash_string) ->
        {number, hash_string}
      end)

    hash_string_by_number
    |> Map.keys()
    |> EthereumJSONRPC.fetch_beneficiaries(json_rpc_named_arguments)
    |> case do
      {:ok, %FetchedBeneficiaries{params_set: params_set} = fetched_beneficiaries} ->
        consensus_params_set = consensus_params_set(params_set, hash_string_by_number)

        %FetchedBeneficiaries{fetched_beneficiaries | params_set: consensus_params_set}

      {:error, reason} ->
        Logger.error(fn -> ["Could not fetch beneficiaries: ", inspect(reason)] end)

        error =
          case reason do
            %{code: code, message: message} -> %{code: code, message: message}
            _ -> %{code: -1, message: inspect(reason)}
          end

        errors =
          Enum.map(hash_string_by_number, fn {number, _} when is_integer(number) ->
            Map.put(error, :data, %{block_number: number})
          end)

        %FetchedBeneficiaries{errors: errors}

      :ignore ->
        %FetchedBeneficiaries{}
    end
  end

  defp consensus_params_set(params_set, hash_string_by_number) do
    params_set
    |> Enum.filter(fn %{block_number: block_number, block_hash: block_hash_string}
                      when is_integer(block_number) and is_binary(block_hash_string) ->
      case Map.fetch!(hash_string_by_number, block_number) do
        ^block_hash_string ->
          true

        other_block_hash_string ->
          Logger.debug(fn ->
            [
              "fetch beneficiaries reported block number (",
              to_string(block_number),
              ") maps to different (",
              other_block_hash_string,
              ") block hash than the one from getBlock (",
              block_hash_string,
              "). A reorg has occurred."
            ]
          end)

          :telemetry.execute([:indexer, :blocks, :reorgs], %{count: 1})

          false
      end
    end)
    |> Enum.into(MapSet.new())
  end

  defp beneficiaries_with_gas_payment(blocks, beneficiary_params_set, transactions_with_receipts) do
    case Application.get_env(:indexer, :fetch_rewards_way) do
      "manual" ->
        beneficiary_params_set

      _ ->
        beneficiary_params_set
        |> add_gas_payments(transactions_with_receipts, blocks)
        |> BlockReward.reduce_uncle_rewards()
    end
  end

  defp add_gas_payments(beneficiaries, transactions, blocks) do
    transactions_by_block_number = Enum.group_by(transactions, & &1.block_number)

    Enum.map(beneficiaries, fn beneficiary ->
      case beneficiary.address_type do
        :validator ->
          block_hash = beneficiary.block_hash

          block = find_block(blocks, block_hash)

          block_miner_hash = block.miner_hash

          {:ok, block_miner} = Chain.string_to_address_hash(block_miner_hash)
          %{payout_key: block_miner_payout_address} = Reward.get_validator_payout_key_by_mining(block_miner)

          reward_with_gas(block_miner_payout_address, beneficiary, transactions_by_block_number)

        _ ->
          beneficiary
      end
    end)
  end

  defp reward_with_gas(block_miner_payout_address, beneficiary, transactions_by_block_number) do
    {:ok, beneficiary_address} = Chain.string_to_address_hash(beneficiary.address_hash)

    "0x" <> minted_hex = beneficiary.reward
    {minted, _} = if minted_hex == "", do: {0, ""}, else: Integer.parse(minted_hex, 16)

    if block_miner_payout_address && beneficiary_address.bytes == block_miner_payout_address.bytes do
      gas_payment = gas_payment(beneficiary, transactions_by_block_number)

      %{beneficiary | reward: minted + gas_payment}
    else
      %{beneficiary | reward: minted}
    end
  end

  defp find_block(blocks, block_hash) do
    blocks
    |> Enum.filter(fn block -> block.hash == block_hash end)
    |> Enum.at(0)
  end

  defp gas_payment(transactions) when is_list(transactions) do
    transactions
    |> Stream.map(&(&1.gas_used * &1.gas_price))
    |> Enum.sum()
  end

  defp gas_payment(%{block_number: block_number}, transactions_by_block_number)
       when is_map(transactions_by_block_number) do
    case Map.fetch(transactions_by_block_number, block_number) do
      {:ok, transactions} -> gas_payment(transactions)
      :error -> 0
    end
  end

  # `fetched_balance_block_number` is needed for the `CoinBalanceFetcher`, but should not be used for `import` because the
  # balance is not known yet.
  defp pop_address_hash_to_fetched_balance_block_number(options) do
    {address_hash_fetched_balance_block_number_pairs, import_options} =
      get_and_update_in(options, [:addresses, :params, Access.all()], &pop_hash_fetched_balance_block_number/1)

    address_hash_to_fetched_balance_block_number = Map.new(address_hash_fetched_balance_block_number_pairs)

    {address_hash_to_fetched_balance_block_number, import_options}
  end

  defp pop_hash_fetched_balance_block_number(
         %{
           fetched_coin_balance_block_number: fetched_coin_balance_block_number,
           hash: hash
         } = address_params
       ) do
    {{hash, fetched_coin_balance_block_number}, Map.delete(address_params, :fetched_coin_balance_block_number)}
  end
end
