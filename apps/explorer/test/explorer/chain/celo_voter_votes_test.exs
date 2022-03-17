defmodule Explorer.Chain.CeloVoterVotesTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{Chain, Repo}

  alias Chain.{Address, Block, CeloVoterVotes}

  describe "previous_epoch_non_zero_voter_votes/2" do
    test "returns non-zero voter votes combinations" do
      %Address{hash: voter_1_address_hash} = insert(:address)
      %Address{hash: voter_2_address_hash} = insert(:address)
      %Address{hash: group_1_address_hash} = insert(:address)
      %Address{hash: group_2_address_hash} = insert(:address)
      %Block{hash: block_1_hash, number: block_1_number} = insert(:block, number: 17_280)

      insert(
        :celo_voter_votes,
        account_hash: voter_1_address_hash,
        group_hash: group_1_address_hash,
        block_hash: block_1_hash,
        block_number: block_1_number
      )

      insert(
        :celo_voter_votes,
        account_hash: voter_1_address_hash,
        active_votes: Decimal.new(5),
        group_hash: group_2_address_hash,
        block_hash: block_1_hash,
        block_number: block_1_number
      )

      insert(
        :celo_voter_votes,
        account_hash: voter_2_address_hash,
        active_votes: Decimal.new(0),
        group_hash: group_1_address_hash,
        block_hash: block_1_hash,
        block_number: block_1_number
      )

      assert CeloVoterVotes.previous_epoch_non_zero_voter_votes(34_560) == [
               %{
                 account_hash: voter_1_address_hash,
                 group_hash: group_1_address_hash
               },
               %{
                 account_hash: voter_1_address_hash,
                 group_hash: group_2_address_hash
               }
             ]
    end
  end
end
