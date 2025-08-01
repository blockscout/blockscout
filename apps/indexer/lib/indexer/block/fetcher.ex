defmodule Indexer.Block.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges.
  """

  use Spandex.Decorators

  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias EthereumJSONRPC.{Blocks, FetchedBeneficiaries}
  alias Explorer.Chain
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.Cache.Blocks, as: BlocksCache
  alias Explorer.Chain.Cache.{Accounts, BlockNumber, Transactions, Uncles}
  alias Explorer.Chain.Filecoin.PendingAddressOperation, as: FilecoinPendingAddressOperation
  alias Explorer.Chain.{Address, Block, Hash, Import, Transaction, Wei}
  alias Indexer.Block.Fetcher.Receipts
  alias Indexer.Fetcher.Arbitrum.MessagesToL2Matcher, as: ArbitrumMessagesToL2Matcher
  alias Indexer.Fetcher.Celo.EpochBlockOperations, as: CeloEpochBlockOperations
  alias Indexer.Fetcher.Celo.EpochLogs, as: CeloEpochLogs
  alias Indexer.Fetcher.CoinBalance.Catchup, as: CoinBalanceCatchup
  alias Indexer.Fetcher.CoinBalance.Realtime, as: CoinBalanceRealtime
  alias Indexer.Fetcher.Filecoin.AddressInfo, as: FilecoinAddressInfo
  alias Indexer.Fetcher.PolygonZkevm.BridgeL1Tokens, as: PolygonZkevmBridgeL1Tokens
  alias Indexer.Fetcher.TokenInstance.Realtime, as: TokenInstanceRealtime

  alias Indexer.{Prometheus, TokenBalances, Tracer}

  alias Indexer.Fetcher.{
    Beacon.Blob,
    BlockReward,
    ContractCode,
    InternalTransaction,
    ReplacedTransaction,
    SignedAuthorizationStatus,
    Token,
    TokenBalance,
    UncleBlock
  }

  alias Indexer.Transform.{
    AddressCoinBalances,
    Addresses,
    AddressTokenBalances,
    MintTransfers,
    SignedAuthorizations,
    TokenInstances,
    TokenTransfers,
    TransactionActions
  }

  alias Indexer.Transform.Stability.Validators, as: StabilityValidators

  alias Indexer.Transform.Optimism.Withdrawals, as: OptimismWithdrawals

  alias Indexer.Transform.PolygonEdge.{DepositExecutes, Withdrawals}

  alias Indexer.Transform.Scroll.L1FeeParams, as: ScrollL1FeeParams

  alias Indexer.Transform.Arbitrum.Messaging, as: ArbitrumMessaging
  alias Indexer.Transform.Shibarium.Bridge, as: ShibariumBridge

  alias Indexer.Transform.Blocks, as: TransformBlocks
  alias Indexer.Transform.PolygonZkevm.Bridge, as: PolygonZkevmBridge

  alias Indexer.Transform.Celo.L1Epochs, as: CeloL1Epochs
  alias Indexer.Transform.Celo.L2Epochs, as: CeloL2Epochs
  alias Indexer.Transform.Celo.TransactionGasTokens, as: CeloTransactionGasTokens
  alias Indexer.Transform.Celo.TransactionTokenTransfers, as: CeloTransactionTokenTransfers

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
                transactions: Import.Runner.options()
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

  @decorate span(tracer: Tracer)
  @spec fetch_and_import_range(t, Range.t(), map) ::
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
        _.._//_ = range,
        additional_options \\ %{}
      )
      when callback_module != nil do
    {fetch_time, fetch_result} =
      :timer.tc(fn -> EthereumJSONRPC.fetch_blocks_by_range(range, json_rpc_named_arguments) end)

    with {:blocks,
          {:ok,
           %Blocks{
             blocks_params: blocks_params,
             transactions_params: transactions_params_without_receipts,
             withdrawals_params: withdrawals_params,
             block_second_degree_relations_params: block_second_degree_relations_params,
             errors: blocks_errors
           } = fetched_blocks}} <- {:blocks, fetch_result},
         blocks = TransformBlocks.transform_blocks(blocks_params),
         {:receipts, {:ok, receipt_params}} <- {:receipts, Receipts.fetch(state, transactions_params_without_receipts)},
         %{logs: receipt_logs, receipts: receipts} = receipt_params,
         transactions_with_receipts = Receipts.put(transactions_params_without_receipts, receipts),
         celo_epoch_logs = CeloEpochLogs.fetch(blocks, json_rpc_named_arguments),
         logs = maybe_set_new_log_index(receipt_logs) ++ celo_epoch_logs,
         %{token_transfers: token_transfers, tokens: tokens} = TokenTransfers.parse(logs),
         %{token_transfers: celo_native_token_transfers, tokens: celo_tokens} =
           CeloTransactionTokenTransfers.parse_transactions(transactions_with_receipts),
         celo_gas_tokens = CeloTransactionGasTokens.parse(transactions_with_receipts),
         token_transfers = token_transfers ++ celo_native_token_transfers,
         celo_l1_epochs = CeloL1Epochs.parse(blocks),
         celo_l2_epochs = CeloL2Epochs.parse(logs),
         tokens = Enum.uniq(tokens ++ celo_tokens),
         %{transaction_actions: transaction_actions} = TransactionActions.parse(logs),
         %{mint_transfers: mint_transfers} = MintTransfers.parse(logs),
         optimism_withdrawals =
           if(callback_module == Indexer.Block.Realtime.Fetcher, do: OptimismWithdrawals.parse(logs), else: []),
         polygon_edge_withdrawals =
           if(callback_module == Indexer.Block.Realtime.Fetcher, do: Withdrawals.parse(logs), else: []),
         polygon_edge_deposit_executes =
           if(callback_module == Indexer.Block.Realtime.Fetcher,
             do: DepositExecutes.parse(logs),
             else: []
           ),
         scroll_l1_fee_params =
           if(callback_module == Indexer.Block.Realtime.Fetcher,
             do: ScrollL1FeeParams.parse(logs),
             else: []
           ),
         shibarium_bridge_operations =
           if(callback_module == Indexer.Block.Realtime.Fetcher,
             do: ShibariumBridge.parse(blocks, transactions_with_receipts, logs),
             else: []
           ),
         polygon_zkevm_bridge_operations =
           if(callback_module == Indexer.Block.Realtime.Fetcher,
             do: PolygonZkevmBridge.parse(blocks, logs),
             else: []
           ),
         {arbitrum_xlevel_messages, arbitrum_transactions_for_further_handling} =
           ArbitrumMessaging.parse(transactions_with_receipts, logs),
         %FetchedBeneficiaries{params_set: beneficiary_params_set, errors: beneficiaries_errors} =
           fetch_beneficiaries(blocks, transactions_with_receipts, json_rpc_named_arguments),
         addresses =
           Addresses.extract_addresses(%{
             block_reward_contract_beneficiaries: MapSet.to_list(beneficiary_params_set),
             blocks: blocks,
             logs: logs,
             mint_transfers: mint_transfers,
             shibarium_bridge_operations: shibarium_bridge_operations,
             token_transfers: token_transfers,
             transactions: transactions_with_receipts,
             transaction_actions: transaction_actions,
             withdrawals: withdrawals_params,
             polygon_zkevm_bridge_operations: polygon_zkevm_bridge_operations
           }),
         coin_balances_params_set =
           %{
             beneficiary_params: MapSet.to_list(beneficiary_params_set),
             blocks_params: blocks,
             logs_params: logs,
             transactions_params: transactions_with_receipts,
             withdrawals: withdrawals_params
           }
           |> AddressCoinBalances.params_set(),
         beneficiaries_with_gas_payment =
           beneficiaries_with_gas_payment(blocks, beneficiary_params_set, transactions_with_receipts),
         token_transfers_with_token = token_transfers_merge_token(token_transfers, tokens),
         address_token_balances =
           AddressTokenBalances.params_set(%{token_transfers_params: token_transfers_with_token}),
         transaction_actions =
           Enum.map(transaction_actions, fn action -> Map.put(action, :data, Map.delete(action.data, :block_number)) end),
         token_instances = TokenInstances.params_set(%{token_transfers_params: token_transfers}),
         stability_validators = StabilityValidators.parse(blocks),
         basic_import_options = %{
           addresses: %{params: addresses},
           address_coin_balances: %{params: coin_balances_params_set},
           address_token_balances: %{params: address_token_balances},
           address_current_token_balances: %{
             params: address_token_balances |> MapSet.to_list() |> TokenBalances.to_address_current_token_balances()
           },
           blocks: %{params: blocks},
           block_second_degree_relations: %{params: block_second_degree_relations_params},
           block_rewards: %{errors: beneficiaries_errors, params: beneficiaries_with_gas_payment},
           logs: %{params: logs},
           token_transfers: %{params: token_transfers},
           tokens: %{params: tokens},
           transactions: %{params: transactions_with_receipts},
           withdrawals: %{params: withdrawals_params},
           token_instances: %{params: token_instances},
           signed_authorizations: %{params: SignedAuthorizations.parse(transactions_with_receipts)}
         },
         chain_type_import_options =
           %{
             transactions_with_receipts: transactions_with_receipts,
             optimism_withdrawals: optimism_withdrawals,
             polygon_edge_withdrawals: polygon_edge_withdrawals,
             polygon_edge_deposit_executes: polygon_edge_deposit_executes,
             polygon_zkevm_bridge_operations: polygon_zkevm_bridge_operations,
             scroll_l1_fee_params: scroll_l1_fee_params,
             shibarium_bridge_operations: shibarium_bridge_operations,
             celo_gas_tokens: celo_gas_tokens,
             celo_epochs: celo_l1_epochs ++ celo_l2_epochs,
             arbitrum_messages: arbitrum_xlevel_messages,
             stability_validators: stability_validators
           }
           |> extend_with_zilliqa_import_options(fetched_blocks),
         {:ok, inserted} <-
           __MODULE__.import(
             state,
             basic_import_options |> Map.merge(additional_options) |> import_options(chain_type_import_options)
           ),
         {:transaction_actions, {:ok, inserted_transaction_actions}} <-
           {:transaction_actions,
            Chain.import(%{
              transaction_actions: %{params: transaction_actions},
              timeout: :infinity
            })} do
      inserted = Map.merge(inserted, inserted_transaction_actions)
      Prometheus.Instrumenter.block_batch_fetch(fetch_time, callback_module)
      result = {:ok, %{inserted: inserted, errors: blocks_errors}}
      update_block_cache(inserted[:blocks])
      update_transactions_cache(inserted[:transactions])
      update_addresses_cache(inserted[:addresses])
      update_uncles_cache(inserted[:block_second_degree_relations])
      update_withdrawals_cache(inserted[:withdrawals])

      async_match_arbitrum_messages_to_l2(arbitrum_transactions_for_further_handling)

      result
    else
      {step, {:error, reason}} -> {:error, {step, reason}}
      {:import, {:error, step, failed_value, changes_so_far}} -> {:error, {step, failed_value, changes_so_far}}
    end
  end

  defp import_options(basic_import_options, chain_specific_import_options) do
    chain_type = Application.get_env(:explorer, :chain_type)
    do_import_options(chain_type, basic_import_options, chain_specific_import_options)
  end

  defp do_import_options(:ethereum, basic_import_options, %{transactions_with_receipts: transactions_with_receipts}) do
    basic_import_options
    |> Map.put_new(:beacon_blob_transactions, %{
      params: transactions_with_receipts |> Enum.filter(&Map.has_key?(&1, :max_fee_per_blob_gas))
    })
  end

  defp do_import_options(:optimism, basic_import_options, %{optimism_withdrawals: optimism_withdrawals}) do
    basic_import_options
    |> Map.put_new(:optimism_withdrawals, %{params: optimism_withdrawals})
  end

  defp do_import_options(:polygon_edge, basic_import_options, %{
         polygon_edge_withdrawals: polygon_edge_withdrawals,
         polygon_edge_deposit_executes: polygon_edge_deposit_executes
       }) do
    basic_import_options
    |> Map.put_new(:polygon_edge_withdrawals, %{params: polygon_edge_withdrawals})
    |> Map.put_new(:polygon_edge_deposit_executes, %{params: polygon_edge_deposit_executes})
  end

  defp do_import_options(:polygon_zkevm, basic_import_options, %{
         polygon_zkevm_bridge_operations: polygon_zkevm_bridge_operations
       }) do
    basic_import_options
    |> Map.put_new(:polygon_zkevm_bridge_operations, %{params: polygon_zkevm_bridge_operations})
  end

  defp do_import_options(:scroll, basic_import_options, %{scroll_l1_fee_params: scroll_l1_fee_params}) do
    basic_import_options
    |> Map.put_new(:scroll_l1_fee_params, %{params: scroll_l1_fee_params})
  end

  defp do_import_options(:shibarium, basic_import_options, %{shibarium_bridge_operations: shibarium_bridge_operations}) do
    basic_import_options
    |> Map.put_new(:shibarium_bridge_operations, %{params: shibarium_bridge_operations})
  end

  defp do_import_options(:celo, basic_import_options, %{celo_gas_tokens: celo_gas_tokens, celo_epochs: celo_epochs}) do
    tokens =
      basic_import_options
      |> Map.get(:tokens, %{})
      |> Map.get(:params, [])

    basic_import_options
    |> Map.put_new(:celo_epochs, %{params: celo_epochs})
    |> Map.put(
      :tokens,
      %{params: (tokens ++ celo_gas_tokens) |> Enum.uniq()}
    )
  end

  defp do_import_options(:arbitrum, basic_import_options, %{arbitrum_messages: arbitrum_xlevel_messages}) do
    basic_import_options
    |> Map.put_new(:arbitrum_messages, %{params: arbitrum_xlevel_messages})
  end

  defp do_import_options(:zilliqa, basic_import_options, %{
         zilliqa_quorum_certificates: zilliqa_quorum_certificates,
         zilliqa_aggregate_quorum_certificates: zilliqa_aggregate_quorum_certificates,
         zilliqa_nested_quorum_certificates: zilliqa_nested_quorum_certificates
       }) do
    basic_import_options
    |> Map.put_new(:zilliqa_quorum_certificates, %{params: zilliqa_quorum_certificates})
    |> Map.put_new(:zilliqa_aggregate_quorum_certificates, %{params: zilliqa_aggregate_quorum_certificates})
    |> Map.put_new(:zilliqa_nested_quorum_certificates, %{params: zilliqa_nested_quorum_certificates})
  end

  defp do_import_options(:stability, basic_import_options, %{stability_validators: stability_validators}) do
    basic_import_options
    |> Map.put_new(:stability_validators, %{params: stability_validators})
  end

  defp do_import_options(_chain_type, basic_import_options, _chain_specific_import_options) do
    basic_import_options
  end

  defp extend_with_zilliqa_import_options(chain_type_import_options, fetched_blocks) do
    chain_type_import_options
    |> Map.merge(%{
      zilliqa_quorum_certificates: Map.get(fetched_blocks, :zilliqa_quorum_certificates_params, []),
      zilliqa_aggregate_quorum_certificates: Map.get(fetched_blocks, :zilliqa_aggregate_quorum_certificates_params, []),
      zilliqa_nested_quorum_certificates: Map.get(fetched_blocks, :zilliqa_nested_quorum_certificates_params, [])
    })
  end

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

  defp update_withdrawals_cache([_ | _] = withdrawals) do
    %{index: index} = List.last(withdrawals)
    Chain.upsert_count_withdrawals(index)
  end

  defp update_withdrawals_cache(_) do
    :ok
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

    {import_time, result} = :timer.tc(fn -> callback_module.import(state, options_with_broadcast) end)

    no_blocks_to_import = length(options_with_broadcast.blocks.params)

    if no_blocks_to_import != 0 do
      Prometheus.Instrumenter.block_import(import_time / no_blocks_to_import, callback_module)
    end

    result
  end

  def async_import_token_instances(%{token_transfers: token_transfers}) do
    TokenInstanceRealtime.async_fetch(token_transfers)
  end

  def async_import_token_instances(_), do: :ok

  def async_import_blobs(%{blocks: blocks}, realtime?) do
    timestamps =
      blocks
      |> Enum.filter(fn block -> block |> Map.get(:blob_gas_used, 0) > 0 end)
      |> Enum.map(&Map.get(&1, :timestamp))

    if not Enum.empty?(timestamps) do
      Blob.async_fetch(timestamps, realtime?)
    end
  end

  def async_import_blobs(_, _), do: :ok

  def async_import_block_rewards([], _realtime?), do: :ok

  def async_import_block_rewards(errors, realtime?) when is_list(errors) do
    errors
    |> block_reward_errors_to_block_numbers()
    |> BlockReward.async_fetch(realtime?)
  end

  def async_import_coin_balances(%{addresses: addresses}, %{
        address_hash_to_fetched_balance_block_number: address_hash_to_block_number
      }) do
    addresses
    |> Enum.map(fn %Address{hash: address_hash} ->
      block_number = Map.fetch!(address_hash_to_block_number, to_string(address_hash))
      %{address_hash: address_hash, block_number: block_number}
    end)
    |> CoinBalanceCatchup.async_fetch_balances()
  end

  def async_import_coin_balances(_, _), do: :ok

  def async_import_realtime_coin_balances(%{address_coin_balances: balances}) do
    CoinBalanceRealtime.async_fetch_balances(balances)
  end

  def async_import_realtime_coin_balances(_), do: :ok

  def async_import_created_contract_codes(%{transactions: transactions}, realtime?) do
    ContractCode.async_fetch(transactions, realtime?, 10_000)
  end

  def async_import_created_contract_codes(_, _), do: :ok

  def async_import_internal_transactions(%{blocks: blocks} = imported, realtime?) do
    blocks
    |> Enum.map(fn %Block{number: block_number} -> block_number end)
    |> InternalTransaction.async_fetch(Map.get(imported, :transactions, []), realtime?, 10_000)
  end

  def async_import_internal_transactions(_, _), do: :ok

  def async_import_tokens(%{tokens: tokens}, realtime?) do
    tokens
    |> Enum.map(& &1.contract_address_hash)
    |> Token.async_fetch(realtime?)
  end

  def async_import_tokens(_, _), do: :ok

  def async_import_token_balances(%{address_token_balances: token_balances}, realtime?) do
    TokenBalance.async_fetch(token_balances, realtime?)
  end

  def async_import_token_balances(_, _), do: :ok

  def async_import_uncles(%{block_second_degree_relations: block_second_degree_relations}, realtime?) do
    UncleBlock.async_fetch_blocks(block_second_degree_relations, realtime?)
  end

  def async_import_uncles(_, _), do: :ok

  def async_import_replaced_transactions(%{transactions: transactions}, realtime?) do
    transactions
    |> Enum.flat_map(fn
      %Transaction{block_hash: %Hash{} = block_hash, nonce: nonce, from_address_hash: %Hash{} = from_address_hash} ->
        [%{block_hash: block_hash, nonce: nonce, from_address_hash: from_address_hash}]

      %Transaction{block_hash: nil} ->
        []
    end)
    |> ReplacedTransaction.async_fetch(realtime?, 10_000)
  end

  def async_import_replaced_transactions(_, _), do: :ok

  @doc """
  Fills a buffer of L1 token addresses to handle it asynchronously in
  the Indexer.Fetcher.PolygonZkevm.BridgeL1Tokens module. The addresses are
  taken from the `operations` list.
  """
  @spec async_import_polygon_zkevm_bridge_l1_tokens(map()) :: :ok
  def async_import_polygon_zkevm_bridge_l1_tokens(%{polygon_zkevm_bridge_operations: operations}) do
    PolygonZkevmBridgeL1Tokens.async_fetch(operations)
  end

  def async_import_polygon_zkevm_bridge_l1_tokens(_), do: :ok

  def async_import_celo_epoch_block_operations(%{celo_epochs: epochs}, realtime?) do
    CeloEpochBlockOperations.async_fetch(epochs, realtime?)
  end

  def async_import_celo_epoch_block_operations(_, _), do: :ok

  def async_import_filecoin_addresses_info(%{addresses: addresses}, realtime?) do
    addresses
    |> Enum.map(&%FilecoinPendingAddressOperation{address_hash: &1.hash})
    |> FilecoinAddressInfo.async_fetch(realtime?)
  end

  def async_import_filecoin_addresses_info(_, _), do: :ok

  def async_import_signed_authorizations_statuses(
        %{transactions: transactions, signed_authorizations: signed_authorizations},
        realtime?
      ) do
    SignedAuthorizationStatus.async_fetch(transactions, signed_authorizations, realtime?)
  end

  def async_import_signed_authorizations_statuses(_, _), do: :ok

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
    |> Block.block_reward_by_parts(transactions)
    |> reward_parts_to_beneficiaries()
  end

  defp reward_parts_to_beneficiaries(reward_parts) do
    reward =
      reward_parts.static_reward
      |> Wei.sum(reward_parts.transaction_fees)
      |> Wei.sub(reward_parts.burnt_fees)
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
    {{String.downcase(hash), fetched_coin_balance_block_number},
     Map.delete(address_params, :fetched_coin_balance_block_number)}
  end

  def token_transfers_merge_token(token_transfers, tokens) do
    Enum.map(token_transfers, fn token_transfer ->
      token =
        Enum.find(tokens, fn token ->
          token.contract_address_hash == token_transfer.token_contract_address_hash
        end)

      Map.put(token_transfer, :token, token)
    end)
  end

  # Asynchronously schedules matching of Arbitrum L1-to-L2 messages where the message ID is hashed.
  @spec async_match_arbitrum_messages_to_l2([map()]) :: :ok
  defp async_match_arbitrum_messages_to_l2([]), do: :ok

  defp async_match_arbitrum_messages_to_l2(transactions_with_messages_from_l1) do
    ArbitrumMessagesToL2Matcher.async_discover_match(transactions_with_messages_from_l1)
  end

  # workaround for cases when RPC send logs with same index within one block
  defp maybe_set_new_log_index(logs) do
    logs
    |> Enum.group_by(& &1.block_hash)
    |> Enum.map(fn {block_hash, logs_per_block} ->
      if logs_per_block |> Enum.frequencies_by(& &1.index) |> Map.values() |> Enum.max() == 1 do
        logs_per_block
      else
        Logger.error("Found logs with same index within one block: #{block_hash}")

        logs_per_block
        |> Enum.sort_by(&{&1.transaction_index, &1.index, &1.transaction_hash})
        |> Enum.with_index(&%{&1 | index: &2})
      end
    end)
    |> List.flatten()
  end
end
