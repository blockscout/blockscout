defmodule Indexer.Fetcher.Celo.EpochRewards do
  import Ecto.Query, only: [from: 2]

  alias ABI.FunctionSelector

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer.Chain
  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.Celo.PendingEpochBlockOperation
  alias Explorer.Chain.{Block, Hash, Log, TokenTransfer}

  alias Explorer.Repo
  alias Explorer.SmartContract.Reader

  import Explorer.Chain.Celo.Helper,
    only: [
      blocks_per_epoch: 0,
      epoch_block?: 1
    ]

  alias Indexer.Helper
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Transform.Addresses
  alias Indexer.Transform.Celo.ValidatorEpochPaymentDistributions
  # todo: would be better to define this func somewhere else or use another one
  # similar
  import Indexer.Transform.TransactionActions, only: [read_contracts_with_retries: 3]

  require Logger

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Indexer.Fetcher.Celo.EpochRewards.Supervisor, as: EpochRewardsSupervisor

  @behaviour BufferedTask

  @default_max_batch_size 1
  @default_max_concurrency 1

  @repeated_request_max_retries 3

  @calculate_target_epoch_rewards_abi [
    %{
      "name" => "calculateTargetEpochRewards",
      "type" => "function",
      "payable" => false,
      "constant" => true,
      "stateMutability" => "view",
      "inputs" => [],
      "outputs" => [
        %{"type" => "uint256"},
        %{"type" => "uint256"},
        %{"type" => "uint256"},
        %{"type" => "uint256"}
      ]
    }
  ]

  # @calculate_target_epoch_rewards_abi_with_method_id @calculate_target_epoch_rewards_abi
  #                                                    |> Reader.get_abi_with_method_id()

  @magic_block_number 9 * blocks_per_epoch()

  @validator_group_vote_activated_topic "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe"

  @validator_group_vote_activated_event_abi [
    %{
      "name" => "ValidatorGroupVoteActivated",
      "type" => "event",
      "anonymous" => false,
      "inputs" => [
        %{
          "indexed" => true,
          "name" => "account",
          "type" => "address"
        },
        %{
          "indexed" => true,
          "name" => "group",
          "type" => "address"
        },
        %{
          "indexed" => false,
          "name" => "value",
          "type" => "uint256"
        },
        %{
          "indexed" => false,
          "name" => "units",
          "type" => "uint256"
        }
      ]
    }
  ]

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
    Helper.json_rpc_named_arguments(rpc_url)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    dbg(init_options)
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
      filtered_entries = Enum.filter(entries, &epoch_block?(&1.block_number))
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
  def run(entries, _json_rpc_named_arguments) do
    [entry] = entries

    fetch_epoch(entry)
    |> case do
      {:ok, _imported} ->
        Logger.info("Fetched epoch rewards for block number: #{entry.block_number}")
        :ok

      error ->
        Logger.error(fn ->
          [
            "Could not fetch epoch rewards for block number: #{entry.block_number}",
            "block hash: #{entry.block_hash}",
            inspect(error)
          ]
        end)

        :retry
    end

    # todo: remove entry from pending epoch operations
  end

  def fetch_epoch(%{block_number: _, block_hash: block_hash} = entry) do
    epoch_payment_distributions = fetch_epoch_payment_distributions(block_hash)

    with {:ok, voter_rewards} <- fetch_voter_rewards(entry),
         {:ok, epoch_rewards} <- fetch_epoch_rewards(entry),
         # todo: replace `_ignore` with pattern matching on `:ok`
         _ignore <- valid_voter_rewards?(voter_rewards, epoch_rewards),
         {:ok, delegated_payments} <-
           epoch_payment_distributions
           |> Enum.map(& &1.validator_address)
           |> fetch_payment_delegations(entry) do
      validator_and_group_rewards =
        payment_distributions_to_validator_and_group_rewards(
          epoch_payment_distributions,
          entry
        )

      election_rewards =
        Enum.concat([
          validator_and_group_rewards,
          voter_rewards,
          delegated_payments
        ])
        |> Enum.filter(&(&1.amount > 0))

      addresses_params =
        Addresses.extract_addresses(%{
          celo_epoch_election_rewards: election_rewards
        })

      Chain.import(%{
        addresses: %{params: addresses_params},
        celo_epoch_election_rewards: %{params: election_rewards},
        celo_epoch_rewards: %{params: [epoch_rewards]}
      })
    end
  end

  def valid_voter_rewards?(voter_rewards, epoch_rewards) do
    manual_voters_total = voter_rewards |> Enum.map(& &1.amount) |> Enum.sum()

    if manual_voters_total ==
         epoch_rewards.voters_total do
      :ok
    else
      Logger.error(fn ->
        [
          "Total voter rewards do not match.",
          "Amount calculated manually: #{manual_voters_total}",
          "Amount returned by `calculateTargetEpochRewards`: #{epoch_rewards.voters_total}"
        ]
      end)

      {:error, :total_voter_rewards_do_not_match}
    end
  end

  def fetch_epoch_payment_distributions(block_hash) do
    epoch_payment_distributions_signature = ValidatorEpochPaymentDistributions.signature()
    validators_contract_address = CeloCoreContracts.get_address(:validators)

    from(
      log in Log,
      where:
        log.block_hash == ^block_hash and
          log.address_hash == ^validators_contract_address and
          log.first_topic == ^epoch_payment_distributions_signature and
          is_nil(log.transaction_hash),
      select: log
    )
    |> Repo.all()
    |> ValidatorEpochPaymentDistributions.parse()
  end

  defp event_to_account_and_group(event) do
    {:ok, %FunctionSelector{},
     [
       {"account", "address", true, account_address},
       {"group", "address", true, group_address},
       _value,
       _units
     ]} =
      @validator_group_vote_activated_event_abi
      |> Log.find_and_decode(
        event,
        event.transaction_hash
      )

    %{
      account_address: "0x" <> Base.encode16(account_address, case: :lower),
      group_address: "0x" <> Base.encode16(group_address, case: :lower)
    }
  end

  # WARN: I couldn't find any example of an epoch where the
  # `getPaymentDelegation` returns not null values.
  # In other words, `fetch_payment_delegations` always returned empty list.
  def fetch_payment_delegations(
        validator_addresses,
        %{block_number: block_number, block_hash: block_hash}
      ) do
    accounts_contract_address = CeloCoreContracts.get_address(:accounts)

    [%{"method_id" => method_id}] =
      @get_payment_delegation_abi
      |> Reader.get_abi_with_method_id()

    requests =
      validator_addresses
      |> Enum.map(fn validator_address ->
        %{
          contract_address: accounts_contract_address,
          method_id: method_id,
          args: [validator_address],
          block_number: block_number
        }
      end)

    usd_token_address_hash = CeloCoreContracts.get_address(:usd_token)
    mint_address = burn_address_hash_string()

    beneficiary_address_to_amount =
      from(
        tt in TokenTransfer.only_consensus_transfers_query(),
        where:
          tt.block_hash == ^block_hash and
            tt.token_contract_address_hash == ^usd_token_address_hash and
            tt.from_address_hash == ^mint_address and
            is_nil(tt.transaction_hash),
        select: {tt.to_address_hash, tt.amount}
      )
      |> Repo.all()
      |> Map.new(fn {address, amount} ->
        {Hash.to_string(address), amount}
      end)

    dbg(beneficiary_address_to_amount)

    with {responses, []} <-
           requests
           |> read_contracts_with_retries(
             @get_payment_delegation_abi,
             @repeated_request_max_retries
           ),
         {:ok, payment_delegations} <-
           responses
           |> Enum.map(fn
             {:ok, [beneficiary_address, fraction]}
             when is_binary(beneficiary_address) and is_integer(fraction) ->
               {:ok, {beneficiary_address, fraction}}

             error ->
               Logger.error("Could not fetch payment delegation: #{inspect(error)}")
               {:error, :could_not_fetch_payment_delegation, error}
           end)
           |> Enum.reduce({:ok, []}, fn
             {:ok, payment_delegation}, {:ok, payment_delegations} ->
               {:ok, [payment_delegation | payment_delegations]}

             _, _ ->
               {:error, :could_not_fetch_payment_delegations}
           end) do
      dbg(payment_delegations)

      rewards =
        validator_addresses
        |> Enum.zip(payment_delegations)
        |> Enum.filter(fn {_, {_, fraction}} -> fraction > 0 end)
        |> Enum.map(fn
          {
            validator_address,
            {beneficiary_address, _}
          } ->
            amount =
              beneficiary_address_to_amount
              |> Map.get(beneficiary_address, 0)

            %{
              block_hash: block_hash,
              account_hash: beneficiary_address,
              amount: amount,
              associated_account_hash: validator_address,
              type: :delegated_payment
            }
        end)

      {:ok, rewards}
    end
  end

  def block_number_to_accounts_with_activated_votes(block_number) do
    query =
      from(
        log in Log,
        where:
          log.block_number < ^block_number and
            log.first_topic == ^@validator_group_vote_activated_topic,
        # `:data` is needed only for decoding, but is not used in the result
        select: [:first_topic, :second_topic, :third_topic, :data],
        distinct: [:first_topic, :second_topic, :third_topic]
      )

    query |> Repo.all() |> Enum.map(&event_to_account_and_group/1)
  end

  # todo: seems like it could be calculated easier
  # https://github.com/celo-org/epochs/blob/main/totalVoterRewards.ts#L11
  def fetch_voter_rewards(%{block_number: block_number, block_hash: block_hash}) do
    election_contract_address = CeloCoreContracts.get_address(:election)

    [%{"method_id" => method_id}] =
      @get_active_votes_for_group_by_account_abi
      |> Reader.get_abi_with_method_id()

    accounts_with_activated_votes = block_number_to_accounts_with_activated_votes(block_number)

    requests =
      accounts_with_activated_votes
      |> Enum.map(fn %{
                       account_address: account_address,
                       group_address: group_address
                     } ->
        (block_number - 1)..block_number
        |> Enum.map(fn block_number ->
          %{
            contract_address: election_contract_address,
            method_id: method_id,
            args: [
              group_address,
              account_address
            ],
            block_number: block_number
          }
        end)
      end)
      |> List.flatten()

    with {responses, []} <-
           read_contracts_with_retries(
             requests,
             @get_active_votes_for_group_by_account_abi,
             @repeated_request_max_retries
           ),
         {:ok, diffs} <-
           responses
           |> Enum.chunk_every(2)
           |> Enum.map(fn
             [ok: [votes_before], ok: [votes_after]]
             when is_integer(votes_before) and
                    is_integer(votes_after) ->
               {:ok, votes_after - votes_before}

             error ->
               Logger.error("Could not fetch votes: #{inspect(error)}")
               {:error, :could_not_fetch_votes, error}
           end)
           |> Enum.reduce({:ok, []}, fn
             {:ok, diff}, {:ok, diffs} ->
               {:ok, [diff | diffs]}

             _, _ ->
               {:error, :could_not_fetch_votes}
           end) do
      # WARN: we do not count Revoked/Activated votes for the last epoch, but
      # should we?
      #
      # See https://github.com/fedor-ivn/celo-blockscout/tree/master/apps/indexer/lib/indexer/fetcher/celo_epoch_data.ex#L179-L187
      # There is no case when those events occur in the epoch block.
      rewards =
        accounts_with_activated_votes
        |> Enum.zip_with(
          diffs,
          fn %{
               account_address: account_address,
               group_address: group_address
             },
             diff ->
            %{
              block_hash: block_hash,
              account_hash: account_address,
              amount: diff,
              associated_account_hash: group_address,
              type: :voter
            }
          end
        )

      {:ok, rewards}
    end
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
          account_hash: validator_address,
          amount: validator_payment,
          associated_account_hash: group_address,
          type: :validator
        },
        %{
          block_hash: block_hash,
          account_hash: group_address,
          amount: group_payment,
          associated_account_hash: validator_address,
          type: :group
        }
      ]
    end)
    |> List.flatten()
  end

  defp fetch_epoch_rewards(%{block_number: block_number, block_hash: block_hash} = _entry) do
    celo_token_contract_address_hash = CeloCoreContracts.get_address(:celo_token)
    mint_address_hash = burn_address_hash_string()
    reserve_contract_address_hash = CeloCoreContracts.get_address(:reserve)

    reserve_bolster =
      from(
        tt in TokenTransfer.only_consensus_transfers_query(),
        where:
          tt.block_hash == ^block_hash and
            tt.token_contract_address_hash == ^celo_token_contract_address_hash and
            tt.from_address_hash == ^mint_address_hash and
            tt.to_address_hash == ^reserve_contract_address_hash and
            is_nil(tt.transaction_hash),
        select: tt.amount
      )
      |> Repo.one() || 0

    # For some reason, the `calculateTargetEpochRewards` method is not available
    # till epoch 10 on mainnet... Thus we introduce the defaults
    if Application.get_env(:explorer, __MODULE__)[:celo_network] == "mainnet" and
         block_number <= @magic_block_number do
      {:ok,
       %{
         per_validator: 0,
         voters_total: 0,
         community_total: 0,
         carbon_offsetting_total: 0
       }}
    else
      do_fetch_target_epoch_rewards(block_number)
    end
    |> case do
      {:ok, target_epoch_rewards} ->
        {:ok,
         target_epoch_rewards
         |> Map.put(
           :reserve_bolster,
           reserve_bolster
         )
         |> Map.put(
           :block_hash,
           block_hash
         )}

      error ->
        error
    end
  end

  defp do_fetch_target_epoch_rewards(block_number) do
    epoch_reward_contract_address = CeloCoreContracts.get_address(:epoch_rewards)

    [%{"method_id" => method_id}] =
      @calculate_target_epoch_rewards_abi
      |> Reader.get_abi_with_method_id()

    requests = [
      %{
        contract_address: epoch_reward_contract_address,
        method_id: method_id,
        args: [],
        block_number: block_number
      }
    ]

    requests
    |> read_contracts_with_retries(
      @calculate_target_epoch_rewards_abi,
      @repeated_request_max_retries
    )
    |> case do
      {
        [
          ok: [
            per_validator,
            voters_total,
            community_total,
            carbon_offsetting_total
          ]
        ],
        []
      } ->
        {:ok,
         %{
           per_validator: per_validator,
           voters_total: voters_total,
           community_total: community_total,
           carbon_offsetting_total: carbon_offsetting_total
         }}

      error ->
        Logger.error(fn ->
          [
            "Could not fetch target epoch rewards:",
            inspect(error)
          ]
        end)

        {:error, :could_not_fetch_target_epoch_rewards}
    end
  end
end
