defmodule Indexer.Fetcher.Celo.EpochRewards do
  # todo: write doc
  @moduledoc false

  import Ecto.Query, only: [from: 2, subquery: 1]

  import Explorer.Helper, only: [decode_data: 2]
  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]
  import Explorer.Chain.Celo.Helper, only: [epoch_block_number?: 1]
  import Indexer.Fetcher.Celo.Helper, only: [abi_to_method_id: 1]

  alias Explorer.Repo
  alias Explorer.Chain
  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.Celo.{PendingEpochBlockOperation, ValidatorGroupVote}
  alias Explorer.Chain.{Block, Hash, Log, TokenTransfer}
  alias Explorer.SmartContract.Reader

  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.Celo.ValidatorGroupVotes
  alias Indexer.Transform.Addresses
  alias Indexer.Transform.Celo.ValidatorEpochPaymentDistributions

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Indexer.Fetcher.Celo.EpochRewards.Supervisor, as: EpochRewardsSupervisor

  @behaviour BufferedTask

  @default_max_batch_size 1
  @default_max_concurrency 1

  @repeated_request_max_retries 3

  @epoch_rewards_distributed_to_voters_topic "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7"

  @get_active_votes_for_group_by_account_abi [
    %{
      "name" => "getActiveVotesForGroupByAccount",
      "type" => "function",
      "payable" => false,
      "constant" => true,
      "stateMutability" => "view",
      "inputs" => [
        %{"name" => "group", "type" => "address"},
        %{"name" => "account", "type" => "address"}
      ],
      "outputs" => [
        %{"type" => "uint256"}
      ]
    }
  ]

  @get_version_number_abi [
    %{
      "name" => "getVersionNumber",
      "type" => "function",
      "payable" => false,
      "constant" => true,
      "stateMutability" => "pure",
      "inputs" => [],
      "outputs" => [
        %{"type" => "uint256"},
        %{"type" => "uint256"},
        %{"type" => "uint256"},
        %{"type" => "uint256"}
      ]
    }
  ]

  # The method `getPaymentDelegation` was introduced in the following. Thus, we
  # set version hardcoded in `getVersionNumber` method.
  #
  # https://github.com/celo-org/celo-monorepo/blob/d7c8936dc529f46d56799365f8b3383a23cc220b/packages/protocol/contracts/common/Accounts.sol#L128-L130
  @get_payment_delegation_available_since_version {1, 1, 3, 0}
  @get_payment_delegation_abi [
    %{
      "name" => "getPaymentDelegation",
      "type" => "function",
      "payable" => false,
      "constant" => true,
      "stateMutability" => "view",
      "inputs" => [
        %{"name" => "account", "type" => "address"}
      ],
      "outputs" => [
        %{"type" => "address"},
        %{"type" => "uint256"}
      ]
    }
  ]

  def json_rpc_named_arguments do
    rpc_url = "https://archive.alfajores.celo-testnet.org"
    IndexerHelper.json_rpc_named_arguments(rpc_url)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  def defaults do
    [
      poll: false,
      flush_interval: :timer.seconds(3),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: Indexer.Fetcher.Celo.EpochRewards.TaskSupervisor,
      metadata: [fetcher: :celo_epoch_rewards]
    ]
  end

  @spec async_fetch([%{block_number: Block.block_number(), block_hash: Hash.Full}]) :: :ok
  def async_fetch(entries, timeout \\ 5000) when is_list(entries) do
    if EpochRewardsSupervisor.disabled?() do
      :ok
    else
      filtered_entries = Enum.filter(entries, &epoch_block_number?(&1.block_number))
      BufferedTask.buffer(__MODULE__, filtered_entries, timeout)
    end
  end

  @impl BufferedTask
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      PendingEpochBlockOperation.stream_epoch_blocks_with_unfetched_rewards(
        initial,
        reducer,
        true
      )

    final
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.Celo.EpochRewards.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(pending_operations, json_rpc_named_arguments) do
    [pending_operation] = pending_operations

    pending_operation
    |> fetch_epoch(json_rpc_named_arguments)
    |> case do
      {:ok, _imported} ->
        Logger.info("Fetched epoch rewards for block number: #{pending_operation.block_number}")
        :ok

      error ->
        Logger.error(
          "Could not fetch epoch rewards for block number #{pending_operation.block_number}: #{inspect(error)}"
        )

        :retry
    end

    :ok
  end

  def fetch_epoch(pending_operation, json_rpc_named_arguments) do
    with {:ok, voter_rewards} <- fetch_voter_rewards(pending_operation, json_rpc_named_arguments),
         {:ok, epoch_rewards} <- fetch_epoch_rewards(pending_operation),
         epoch_payment_distributions = fetch_epoch_payment_distributions(pending_operation),
         {:ok, delegated_payments} <-
           fetch_payment_delegations(pending_operation, epoch_payment_distributions, json_rpc_named_arguments) do
      validator_and_group_rewards =
        payment_distributions_to_validator_and_group_rewards(
          epoch_payment_distributions,
          pending_operation
        )

      dbg(epoch_rewards)
      validate_voter_rewards(pending_operation, voter_rewards)

      election_rewards =
        [
          validator_and_group_rewards,
          voter_rewards,
          delegated_payments
        ]
        |> Enum.concat()
        |> Enum.filter(&(&1.amount > 0))

      addresses_params =
        Addresses.extract_addresses(%{
          celo_election_rewards: election_rewards
        })

      {:ok, imported} =
        Chain.import(%{
          addresses: %{params: addresses_params},
          celo_election_rewards: %{params: election_rewards},
          celo_epoch_rewards: %{params: [epoch_rewards]}
        })

      {:ok, imported}
    end
  end

  def validate_voter_rewards(pending_operation, voter_rewards) do
    manual_voters_total = voter_rewards |> Enum.map(& &1.amount) |> Enum.sum()
    {:ok, election_contract_address} = CeloCoreContracts.get_address(:election, pending_operation.block_number)

    voter_rewards_from_event_total =
      from(
        l in Log,
        where:
          l.block_hash == ^pending_operation.block_hash and
            l.address_hash == ^election_contract_address and
            l.first_topic == ^@epoch_rewards_distributed_to_voters_topic and
            is_nil(l.transaction_hash),
        select: l.data
      )
      |> Repo.all()
      |> Enum.map(fn data ->
        [amount] = decode_data(data, [{:uint, 256}])
        amount
      end)
      |> Enum.sum()

    if voter_rewards_from_event_total == manual_voters_total do
      :ok
    else
      Logger.warning(fn ->
        [
          "Total voter rewards do not match. ",
          "Amount calculated manually: #{manual_voters_total}. ",
          "Amount got from `EpochRewardsDistributedToVoters` events: #{voter_rewards_from_event_total}."
        ]
      end)
    end
  end

  def fetch_epoch_payment_distributions(%{block_number: block_number, block_hash: block_hash}) do
    epoch_payment_distributions_signature = ValidatorEpochPaymentDistributions.signature()
    {:ok, validators_contract_address} = CeloCoreContracts.get_address(:validators, block_number)

    query =
      from(
        log in Log,
        where:
          log.block_hash == ^block_hash and
            log.address_hash == ^validators_contract_address and
            log.first_topic == ^epoch_payment_distributions_signature and
            is_nil(log.transaction_hash),
        select: log
      )

    query |> Repo.all() |> dbg() |> ValidatorEpochPaymentDistributions.parse()
  end

  def fetch_contract_version(address, block_number, json_rpc_named_arguments) do
    [%{"method_id" => method_id}] =
      @get_version_number_abi
      |> Reader.get_abi_with_method_id()

    request = %{
      contract_address: address,
      method_id: method_id,
      args: [],
      block_number: block_number
    }

    IndexerHelper.read_contracts_with_retries(
      [request],
      @get_version_number_abi,
      json_rpc_named_arguments,
      @repeated_request_max_retries,
      false
    )
    |> elem(0)
    |> case do
      [ok: [storage, major, minor, patch]] ->
        {:ok, {storage, major, minor, patch}}

      # Celo Core Contracts deployed to a live network without the
      # `getVersionNumber()` function, such as the original set of core
      # contracts, are to be considered version 1.1.0.0.
      #
      # https://docs.celo.org/community/release-process/smart-contracts#core-contracts
      [error: "(-32000) execution reverted"] ->
        {:ok, {1, 1, 0, 0}}

      errors ->
        {:error, errors}
    end
  end

  # WARN: I couldn't find any example of an epoch where the
  # `getPaymentDelegation` returns not null values.
  # In other words, `fetch_payment_delegations` always returned empty list.
  def fetch_payment_delegations(
        %{block_number: block_number, block_hash: block_hash},
        epoch_payment_distributions,
        json_rpc_named_arguments
      ) do
    validator_addresses =
      epoch_payment_distributions
      |> Enum.map(& &1.validator_address)

    [%{"method_id" => method_id}] =
      @get_payment_delegation_abi
      |> Reader.get_abi_with_method_id()

    with {:ok, accounts_contract_address} <- CeloCoreContracts.get_address(:accounts, block_number),
         {:ok, accounts_contract_version} <-
           fetch_contract_version(accounts_contract_address, block_number, json_rpc_named_arguments),
         true <- accounts_contract_version >= @get_payment_delegation_available_since_version,
         {:ok, usd_token_contract_address} <- CeloCoreContracts.get_address(:usd_token, block_number),
         requests =
           validator_addresses
           |> Enum.map(
             &%{
               contract_address: accounts_contract_address,
               method_id: method_id,
               args: [&1],
               block_number: block_number
             }
           ),
         dbg(requests),
         {responses, []} <-
           IndexerHelper.read_contracts_with_retries(
             requests,
             @get_payment_delegation_abi,
             json_rpc_named_arguments,
             @repeated_request_max_retries
           ) do
      mint_address = burn_address_hash_string()

      query =
        from(
          tt in TokenTransfer.only_consensus_transfers_query(),
          where:
            tt.block_hash == ^block_hash and
              tt.token_contract_address_hash == ^usd_token_contract_address and
              tt.from_address_hash == ^mint_address and
              is_nil(tt.transaction_hash),
          select: {tt.to_address_hash, tt.amount}
        )

      beneficiary_address_to_amount =
        query
        |> Repo.all()
        |> Map.new(fn {address, amount} ->
          {Hash.to_string(address), amount}
        end)

      rewards =
        validator_addresses
        |> Enum.zip(responses)
        |> Enum.filter(&match?({_, {:ok, [_, fraction]}} when fraction > 0, &1))
        |> Enum.map(fn
          {validator_address, {:ok, [beneficiary_address, _]}} ->
            amount = Map.get(beneficiary_address_to_amount, beneficiary_address, 0)

            %{
              block_hash: block_hash,
              account_address_hash: beneficiary_address,
              amount: amount,
              associated_account_address_hash: validator_address,
              type: :delegated_payment
            }
        end)

      {:ok, rewards}
    else
      false ->
        Logger.info(fn ->
          [
            "Do not fetch payment delegations since `getPaymentDelegation` ",
            "is not available on block #{block_number}"
          ]
        end)

        {:ok, []}

      error ->
        Logger.error("Could not fetch payment delegations: #{inspect(error)}")
        {:error, :could_not_fetch_payment_delegations}
    end
  end

  def fetch_voter_rewards(
        %{block_number: block_number, block_hash: block_hash},
        json_rpc_named_arguments
      ) do
    :ok = ValidatorGroupVotes.fetch(block_number)

    {:ok, election_contract_address} = CeloCoreContracts.get_address(:election, block_number)

    elected_groups_query =
      from(
        l in Log,
        where:
          l.block_hash == ^block_hash and
            l.address_hash == ^election_contract_address and
            l.first_topic == ^@epoch_rewards_distributed_to_voters_topic and
            is_nil(l.transaction_hash),
        select: fragment("SUBSTRING(? from 13)", l.second_topic)
      )

    query =
      from(
        v in ValidatorGroupVote,
        where:
          v.group_address_hash in subquery(elected_groups_query) and
            v.block_number <= ^block_number,
        distinct: true,
        select: {v.account_address_hash, v.group_address_hash}
      )

    accounts_with_activated_votes =
      query
      |> Repo.all()
      |> Enum.map(fn
        {account_address_hash, group_address_hash} ->
          {
            Hash.to_string(account_address_hash),
            Hash.to_string(group_address_hash)
          }
      end)

    method_id = abi_to_method_id(@get_active_votes_for_group_by_account_abi)

    requests =
      accounts_with_activated_votes
      |> Enum.map(fn {account_address_hash, group_address_hash} ->
        (block_number - 1)..block_number
        |> Enum.map(fn block_number ->
          %{
            contract_address: election_contract_address,
            method_id: method_id,
            args: [
              group_address_hash,
              account_address_hash
            ],
            block_number: block_number
          }
        end)
      end)
      |> Enum.concat()

    {responses, []} =
      IndexerHelper.read_contracts_with_retries(
        requests,
        @get_active_votes_for_group_by_account_abi,
        json_rpc_named_arguments,
        @repeated_request_max_retries
      )

    diffs =
      responses
      |> Enum.chunk_every(2)
      |> Enum.map(fn
        [ok: [votes_before], ok: [votes_after]]
        when is_integer(votes_before) and
               is_integer(votes_after) ->
          votes_after - votes_before
      end)

    # WARN: we do not count Revoked/Activated votes for the last epoch, but
    # should we?
    #
    # See https://github.com/fedor-ivn/celo-blockscout/tree/master/apps/indexer/lib/indexer/fetcher/celo_epoch_data.ex#L179-L187
    # There is no case when those events occur in the epoch block.
    rewards =
      accounts_with_activated_votes
      |> Enum.zip_with(
        diffs,
        fn {account_address_hash, group_address_hash}, diff ->
          %{
            block_hash: block_hash,
            account_address_hash: account_address_hash,
            amount: diff,
            associated_account_address_hash: group_address_hash,
            type: :voter
          }
        end
      )

    {:ok, rewards}
  end

  def payment_distributions_to_validator_and_group_rewards(
        payment_distributions,
        %{block_hash: block_hash}
      ) do
    payment_distributions
    |> Enum.map(fn %{
                     validator_address: validator_address,
                     validator_payment: validator_payment,
                     group_address: group_address,
                     group_payment: group_payment
                   } ->
      [
        %{
          block_hash: block_hash,
          account_address_hash: validator_address,
          amount: validator_payment,
          associated_account_address_hash: group_address,
          type: :validator
        },
        %{
          block_hash: block_hash,
          account_address_hash: group_address,
          amount: group_payment,
          associated_account_address_hash: validator_address,
          type: :group
        }
      ]
    end)
    |> Enum.concat()
  end

  def fetch_epoch_rewards(%{block_number: block_number, block_hash: block_hash} = _entry) do
    with {:ok, celo_token_contract_address_hash} <- CeloCoreContracts.get_address(:celo_token, block_number),
         {:ok, reserve_contract_address_hash} <- CeloCoreContracts.get_address(:reserve, block_number),
         {:ok, community_contract_address_hash} <- CeloCoreContracts.get_address(:governance, block_number),
         {:ok, %{"address" => carbon_offsetting_contract_address_hash}} <-
           CeloCoreContracts.get_event(:epoch_rewards, :carbon_offsetting_fund_set, block_number) do
      mint_address_hash = burn_address_hash_string()

      celo_mint_transfers_query =
        from(
          tt in TokenTransfer.only_consensus_transfers_query(),
          where:
            tt.block_hash == ^block_hash and
              tt.token_contract_address_hash == ^celo_token_contract_address_hash and
              tt.from_address_hash == ^mint_address_hash and
              is_nil(tt.transaction_hash)
        )

      # Every epoch has at least one CELO transfer from the zero address to the
      # reserve. This is how cUSD is minted before it is distributed to
      # validators. If there is only one CELO transfer, then there was no
      # Reserve bolster distribution for that epoch. If there are multiple CELO
      # transfers, then the last one is the Reserve bolster distribution.
      reserve_bolster_transfer_log_index_query =
        from(
          tt in subquery(
            from(
              tt in subquery(celo_mint_transfers_query),
              where: tt.to_address_hash == ^reserve_contract_address_hash,
              order_by: tt.log_index,
              offset: 1
            )
          ),
          select: max(tt.log_index)
        )

      query =
        from(
          tt in subquery(celo_mint_transfers_query),
          where:
            tt.to_address_hash in ^[
              community_contract_address_hash,
              carbon_offsetting_contract_address_hash
            ] or
              tt.log_index == subquery(reserve_bolster_transfer_log_index_query),
          select: {tt.to_address_hash, tt.log_index}
        )

      transfers = query |> Repo.all()

      unique_addresses_count =
        transfers
        |> Enum.map(&elem(&1, 0))
        |> Enum.uniq()
        |> Enum.count()

      address_to_key = %{
        reserve_contract_address_hash => :reserve_bolster_transfer_log_index,
        community_contract_address_hash => :community_transfer_log_index,
        carbon_offsetting_contract_address_hash => :carbon_offsetting_transfer_log_index
      }

      if unique_addresses_count == Enum.count(transfers) do
        epoch_rewards =
          transfers
          |> Enum.reduce(%{}, fn {address, log_index}, acc ->
            key = Map.get(address_to_key, address |> Hash.to_string())
            Map.put(acc, key, log_index)
          end)
          |> Map.put(:block_hash, block_hash)

        {:ok, epoch_rewards}
      else
        {:error, :multiple_transfers_to_same_address}
      end
    end
  end
end
