defmodule Indexer.Fetcher.Celo.EpochBlockOperations.VoterPayments do
  @moduledoc """
  Fetches voter payments for the epoch block.
  """
  import Ecto.Query, only: [from: 2, select: 3]

  import Explorer.Helper,
    only: [
      decode_data: 2,
      abi_to_method_id: 1
    ]

  import Indexer.Helper,
    only: [
      read_contracts_with_retries_by_chunks: 3,
      read_contracts_with_retries: 4
    ]

  alias Explorer.Repo
  alias Indexer.Fetcher.Celo.ValidatorGroupVotes

  alias Explorer.Chain.{
    Cache.CeloCoreContracts,
    Celo.Epoch,
    Celo.ValidatorGroupVote,
    Hash,
    Log
  }

  require Logger

  @repeated_request_max_retries 3

  @requests_chunk_size 100

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

  @get_active_votes_for_group_by_account_method_id @get_active_votes_for_group_by_account_abi
                                                   |> abi_to_method_id()

  @spec fetch(Epoch.t(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          {:error, list()} | {:ok, list()}
  def fetch(
        %Epoch{start_processing_block: start_block, end_processing_block: end_block} = epoch,
        json_rpc_named_arguments
      ) do
    :ok = ValidatorGroupVotes.fetch(end_block.number)

    {:ok, election_contract_address} = CeloCoreContracts.get_address(:election, start_block.number)

    elected_groups_query =
      start_block.number
      |> epoch_rewards_distributed_to_voters_query(end_block.number)
      |> select([l], fragment("SUBSTRING(? from 13)", l.second_topic))

    end_block_number = end_block.number

    query =
      from(
        v in ValidatorGroupVote,
        where:
          v.group_address_hash in subquery(elected_groups_query) and
            v.block_number <= ^end_block_number,
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

    requests =
      accounts_with_activated_votes
      |> Enum.map(fn {account_address_hash, group_address_hash} ->
        (end_block_number - 1)..end_block_number
        |> Enum.map(fn block_number ->
          %{
            contract_address: election_contract_address,
            method_id: @get_active_votes_for_group_by_account_method_id,
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
      read_contracts_with_retries_by_chunks(
        requests,
        @requests_chunk_size,
        fn requests ->
          read_contracts_with_retries(
            requests,
            @get_active_votes_for_group_by_account_abi,
            json_rpc_named_arguments,
            @repeated_request_max_retries
          )
        end
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
            epoch_number: epoch.number,
            account_address_hash: account_address_hash,
            amount: diff,
            associated_account_address_hash: group_address_hash,
            type: :voter
          }
        end
      )

    ok_or_error = validate_voter_rewards(start_block.number, end_block.number, rewards)

    {ok_or_error, rewards}
  end

  defp epoch_rewards_distributed_to_voters_query(start_block_number, end_block_number) do
    {:ok, election_contract_address} = CeloCoreContracts.get_address(:election, start_block_number)

    from(
      l in Log,
      where:
        l.block_number >= ^start_block_number and
          l.block_number <= ^end_block_number and
          l.address_hash == ^election_contract_address and
          l.first_topic == ^@epoch_rewards_distributed_to_voters_topic
    )
  end

  # Validates voter rewards by comparing the sum of what we got from the
  # `EpochRewardsDistributedToVoters` event and the sum of what we calculated
  # manually by fetching the votes for each account that has or had an activated
  # vote.
  defp validate_voter_rewards(start_block_number, end_block_number, voter_rewards) do
    manual_voters_total = voter_rewards |> Enum.map(& &1.amount) |> Enum.sum()

    query =
      start_block_number
      |> epoch_rewards_distributed_to_voters_query(end_block_number)
      |> select([l], l.data)

    voter_rewards_from_event_total =
      query
      |> Repo.all()
      |> Enum.map(fn data ->
        [amount] = decode_data(data, [{:uint, 256}])
        amount
      end)
      |> Enum.sum()

    voter_rewards_count = Enum.count(voter_rewards)
    voter_rewards_diff = voter_rewards_from_event_total - manual_voters_total

    if voter_rewards_diff < voter_rewards_count or voter_rewards_count == 0 do
      :ok
    else
      Logger.warning(fn ->
        [
          "Total voter rewards do not match. ",
          "Amount calculated manually: #{manual_voters_total}. ",
          "Amount got from `EpochRewardsDistributedToVoters` events: #{voter_rewards_from_event_total}. ",
          "Voter rewards count: #{voter_rewards_count}."
        ]
      end)

      :error
    end
  end
end
