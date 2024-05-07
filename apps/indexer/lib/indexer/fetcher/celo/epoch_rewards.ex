defmodule Indexer.Fetcher.Celo.EpochRewards do
  import EthereumJSONRPC,
    only: [
      integer_to_quantity: 1,
      json_rpc: 2
    ]

  import Ecto.Query, only: [from: 2]

  alias ABI.FunctionSelector

  alias EthereumJSONRPC.Logs

  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.Celo.PendingEpochBlockOperation
  alias Explorer.Chain.{Block, Log}
  alias Explorer.Repo
  alias Explorer.SmartContract.Reader

  # import Explorer.Helper, only: [decode_data: 2]

  import Explorer.Chain.Celo.Helper,
    only: [
      blocks_per_epoch: 0,
      epoch_block?: 1
    ]

  alias Indexer.{BufferedTask, Helper, Tracer}

  alias Indexer.Transform.Celo.Epoch.{
    PaymentDelegationTransfers,
    ValidatorEpochPaymentDistributions,
    ReserveBolsterTransferAmount
  }

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

  # @epoch_rewards_abi [
  #   %{
  #     "constant" => true,
  #     "inputs" => [],
  #     "name" => "getTargetGoldTotalSupply",
  #     "outputs" => [
  #       %{"type" => "uint256"}
  #     ],
  #     "payable" => false,
  #     "stateMutability" => "view",
  #     "type" => "function"
  #   },
  #   %{
  #     "constant" => true,
  #     "inputs" => [],
  #     "name" => "getRewardsMultiplier",
  #     "outputs" => [
  #       %{"type" => "uint256"}
  #     ],
  #     "payable" => false,
  #     "stateMutability" => "view",
  #     "type" => "function"
  #   },
  #   %{
  #     "constant" => true,
  #     "inputs" => [],
  #     "name" => "getRewardsMultiplierParameters",
  #     "outputs" => [
  #       %{"type" => "uint256"},
  #       %{"type" => "uint256"},
  #       %{"type" => "uint256"}
  #     ],
  #     "payable" => false,
  #     "stateMutability" => "view",
  #     "type" => "function"
  #   },
  #   %{
  #     "constant" => true,
  #     "inputs" => [],
  #     "name" => "getTargetVotingYieldParameters",
  #     "outputs" => [
  #       %{"type" => "uint256"},
  #       %{"type" => "uint256"},
  #       %{"type" => "uint256"}
  #     ],
  #     "payable" => false,
  #     "stateMutability" => "view",
  #     "type" => "function"
  #   },
  #   %{
  #     "constant" => true,
  #     "inputs" => [],
  #     "name" => "getTargetVotingGoldFraction",
  #     "outputs" => [
  #       %{"type" => "uint256"}
  #     ],
  #     "payable" => false,
  #     "stateMutability" => "view",
  #     "type" => "function"
  #   },
  #   %{
  #     "constant" => true,
  #     "inputs" => [],
  #     "name" => "getVotingGoldFraction",
  #     "outputs" => [
  #       %{"type" => "uint256"}
  #     ],
  #     "payable" => false,
  #     "stateMutability" => "view",
  #     "type" => "function"
  #   }
  # ]

  # @epoch_rewards_abi_with_method_id @epoch_rewards_abi
  #                                   |> Reader.get_abi_with_method_id()

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
  def run(entries, json_rpc_named_arguments) do
    [entry] = entries
    fetch_epoch(entry, json_rpc_named_arguments)
    |> dbg()
    :ok
  end

  def fetch_epoch(%{block_number: block_number, block_hash: _} = entry, json_rpc_named_arguments) do
    with {:ok, logs} <- fetch_logs(block_number, json_rpc_named_arguments),
         epoch_payment_distributions = ValidatorEpochPaymentDistributions.parse(logs),
         {:ok, voter_rewards} <- fetch_voter_rewards(entry),
         {:ok, delegated_payments} <-
           epoch_payment_distributions
           |> Enum.map(& &1.validator_address)
           |> fetch_payment_delegations(logs, entry),
         {:ok, epoch_rewards} <- fetch_epoch_rewards(logs, entry) do
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

      %{
        celo_epoch_election_rewards: %{params: election_rewards},
        celo_epoch_rewards: %{params: [epoch_rewards]}
      }
    end
  end

  def fetch_logs(block_number, json_rpc_named_arguments) do
    requests = [
      Logs.request(
        0,
        %{
          :fromBlock => integer_to_quantity(block_number),
          :toBlock => integer_to_quantity(block_number)
        }
      )
    ]

    error_message = "Could not fetch epoch logs"

    with {:ok, responses} <-
           Helper.repeated_call(
             &json_rpc/2,
             [requests, json_rpc_named_arguments],
             error_message,
             @repeated_request_max_retries
           ) do
      Logs.from_responses(responses)
    end
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
        logs,
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
      beneficiary_address_to_amount = PaymentDelegationTransfers.parse(logs)

      rewards =
        validator_addresses
        |> Enum.zip(payment_delegations)
        |> Enum.filter(fn {_, {_, fraction}} -> fraction > 0 end)
        |> Enum.map(fn
          {
            validator_address,
            {beneficiary_address, _}
          } ->
            %{
              block_hash: block_hash,
              account_hash: beneficiary_address,
              amount:
                beneficiary_address_to_amount
                |> Map.get(beneficiary_address, 0),
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

  defp fetch_epoch_rewards(logs, %{block_number: block_number, block_hash: block_hash} = _entry) do
    reserve_bolster = ReserveBolsterTransferAmount.parse(logs)

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

      _ ->
        {:error, :could_not_fetch_target_epoch_rewards}
    end
  end

  # defp fetch_epoch_rewards(block_number) do
  #   block_number
  #   |> fetch_epoch_rewards_inner(
  #     @epoch_rewards_abi_with_method_id ++
  #       @calculate_target_epoch_rewards_abi_with_method_id,
  #     @epoch_rewards_abi ++
  #       @calculate_target_epoch_rewards_abi
  #   )
  #   |> case do
  #     a -> a
  #   end
  # end

  # defp fetch_epoch_rewards(block_number) do
  #   block_number
  #   |> fetch_epoch_rewards_inner(
  #     @epoch_rewards_abi_with_method_id,
  #     @epoch_rewards_abi
  #   )
  #   |> case do
  #     {[
  #        # getTargetGoldTotalSupply
  #        ok: [target_celo_total_supply],
  #        # getRewardsMultiplier
  #        ok: [rewards_multiplier],
  #        # getRewardsMultiplierParameters
  #        ok: [
  #          rewards_multiplier_max,
  #          rewards_multiplier_under,
  #          rewards_multiplier_over
  #        ],
  #        # getTargetVotingYieldParameters
  #        ok: [
  #          target_voting_yield,
  #          target_voting_yield_max,
  #          target_voting_yield_adjustment_factor
  #        ],
  #        # getTargetVotingGoldFraction
  #        ok: [target_voting_celo_fraction],
  #        # getVotingGoldFraction
  #        ok: [voting_celo_fraction]
  #      ], []} = a ->
  #       a
  #   end
  # end

  # defp fetch_epoch_rewards_inner(block_number, abi_with_method_id, abi) do
  #   # epoch_reward_contract_address = "0xb10ee11244526b94879e1956745ba2e35ae2ba20"
  #   epoch_reward_contract_address = "0x07f007d389883622ef8d4d347b3f78007f28d8b7"

  #   requests =
  #     abi_with_method_id
  #     |> Enum.map(fn %{"method_id" => method_id} ->
  #       %{
  #         contract_address: epoch_reward_contract_address,
  #         method_id: method_id,
  #         args: [],
  #         block_number: block_number
  #       }
  #     end)

  #   read_contracts_with_retries(requests, abi, @repeated_request_max_retries)
  # end
end
