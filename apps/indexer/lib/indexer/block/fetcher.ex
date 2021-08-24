defmodule Indexer.Block.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges.
  """

  use Spandex.Decorators

  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias EthereumJSONRPC.{Blocks, FetchedBeneficiaries}
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, Hash, Import, Transaction}
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.Cache.Blocks, as: BlocksCache
  alias Explorer.Chain.Cache.{Accounts, BlockNumber, Transactions, Uncles}
  alias Indexer.Block.Fetcher.Receipts

  alias Indexer.Fetcher.{
    BlockReward,
    CoinBalance,
    ContractCode,
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
                transactions: Import.Runner.options()
              }
            ) :: Import.all_result()

  # These are all the *default* values for options.
  # DO NOT use them directly in the code.  Get options from `state`.

  @receipts_batch_size 250
  @receipts_concurrency 50

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
  @spec fetch_and_import_range(t, Range.t()) ::
          {:ok, %{inserted: %{}, errors: [EthereumJSONRPC.Transport.error()]}}
          | {:error,
             {step :: atom(), reason :: [%Ecto.Changeset{}] | term()}
             | {step :: atom(), failed_value :: term(), changes_so_far :: term()}}
  def fetch_and_import_range(
        %__MODULE__{
          broadcast: _broadcast,
          callback_module: callback_module,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state,
        _.._ = range
      )
      when callback_module != nil do
    range_list = Enum.to_list(range)

    if Enum.at(range_list, 0) != Enum.at(range_list, -1) do
      Logger.info(["### fetch_and_import_range STARTED ", inspect(range), " ###"])
    end

    with {:blocks,
          {:ok,
           %Blocks{
             blocks_params: blocks_params,
             transactions_params: transactions_params_without_receipts,
             block_second_degree_relations_params: block_second_degree_relations_params,
             errors: blocks_errors
           }}} <- {:blocks, EthereumJSONRPC.fetch_blocks_by_range(range, json_rpc_named_arguments)},
         blocks = TransformBlocks.transform_blocks(blocks_params),
         {:receipts, {:ok, receipt_params}} <- {:receipts, Receipts.fetch(state, transactions_params_without_receipts)},
         %{logs: logs, receipts: receipts} = receipt_params,
         transactions_with_receipts = Receipts.put(transactions_params_without_receipts, receipts),
         %{token_transfers: token_transfers, tokens: tokens} = TokenTransfers.parse(logs),
         %{mint_transfers: mint_transfers} = MintTransfers.parse(logs),
         addresses =
           Addresses.extract_addresses(%{
             blocks: blocks,
             logs: logs,
             mint_transfers: mint_transfers,
             token_transfers: token_transfers,
             transactions: transactions_with_receipts
           }),
         coin_balances_params_set =
           %{
             blocks_params: blocks,
             logs_params: logs,
             transactions_params: transactions_with_receipts
           }
           |> AddressCoinBalances.params_set(),
         coin_balances_params_daily_set =
           %{
             coin_balances_params: coin_balances_params_set,
             blocks: blocks
           }
           |> AddressCoinBalancesDaily.params_set(),
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
               block_rewards: %{errors: [], params: []},
               logs: %{params: logs},
               token_transfers: %{params: token_transfers},
               tokens: %{on_conflict: :nothing, params: tokens},
               transactions: %{params: transactions_with_receipts}
             }
           ) do
      if Enum.at(range_list, 0) != Enum.at(range_list, -1) do
        Logger.info(["### fetch_and_import_range FINISHED ", inspect(range), " ###"])
      end

      Task.async(fn ->
        %FetchedBeneficiaries{params_set: beneficiary_params_set, errors: beneficiaries_errors} =
          fetch_beneficiaries(blocks, json_rpc_named_arguments)

        addresses_from_block_rewards =
          Addresses.extract_addresses(%{
            block_reward_contract_beneficiaries: MapSet.to_list(beneficiary_params_set)
          })

        coin_balances_params_set_from_block_rewards =
          %{
            beneficiary_params: MapSet.to_list(beneficiary_params_set)
          }
          |> AddressCoinBalances.params_set()

        coin_balances_params_daily_set_from_block_rewards =
          %{
            coin_balances_params: coin_balances_params_set_from_block_rewards,
            blocks: blocks
          }
          |> AddressCoinBalancesDaily.params_set()

        beneficiaries_with_gas_payment =
          beneficiary_params_set
          |> add_gas_payments(transactions_with_receipts, blocks)
          |> BlockReward.reduce_uncle_rewards()

        insert_params = %{
          addresses: %{params: addresses_from_block_rewards},
          address_coin_balances: %{params: coin_balances_params_set_from_block_rewards},
          blocks: %{params: []},
          block_rewards: %{errors: beneficiaries_errors, params: beneficiaries_with_gas_payment}
        }

        %MapSet{map: map} = coin_balances_params_daily_set_from_block_rewards

        insert_params =
          if map_size(map) == 0 do
            insert_params
          else
            insert_params
            |> Map.put(:address_coin_balances_daily, %{params: coin_balances_params_daily_set_from_block_rewards})
          end

        {:ok, inserted_from_rewards} =
          __MODULE__.import(
            state,
            insert_params
          )

        update_addresses_cache(inserted_from_rewards[:addresses])
      end)

      result = {:ok, %{inserted: inserted, errors: blocks_errors}}
      update_block_cache(inserted[:blocks])
      update_transactions_cache(inserted[:transactions])
      update_addresses_cache(inserted[:addresses])
      update_uncles_cache(inserted[:block_second_degree_relations])
      result
    else
      {step, {:error, reason}} -> {:error, {step, reason}}
      {:import, {:error, step, failed_value, changes_so_far}} -> {:error, {step, failed_value, changes_so_far}}
    end
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

  defp fetch_beneficiaries(blocks, json_rpc_named_arguments) do
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
