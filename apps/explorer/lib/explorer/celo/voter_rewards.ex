defmodule Explorer.Celo.VoterRewards do
  @moduledoc """
    Module responsible for calculating a voter's rewards for all groups the voter has voted for.
  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Chain.CeloContractEvent
  alias Explorer.Repo

  # The way we calculate voter rewards is by subtracting the previous epoch's last block's votes count from the current
  # epoch's first block's votes count. If the user activated or revoked votes in the previous epoch's last block, we
  # need to take that into consideration, namely subtract any activated and add any revoked votes.
  def subtract_activated_add_revoked(entry) do
    query =
      from(event in CeloContractEvent,
        select:
          fragment(
            "SUM(CAST(params->>'value' AS numeric) * CASE name WHEN ? THEN -1 ELSE 1 END)",
            ^"ValidatorGroupVoteActivated"
          ),
        where: event.name in ["ValidatorGroupVoteActivated", "ValidatorGroupActiveVoteRevoked"],
        where: event.block_number == ^entry.block_number
      )

    query
    |> CeloContractEvent.query_by_voter_param(entry.account_hash)
    |> CeloContractEvent.query_by_group_param(entry.group_hash)
    |> Repo.one(timeout: :infinity)
    |> to_integer_if_not_nil()
  end

  defp to_integer_if_not_nil(nil), do: 0
  defp to_integer_if_not_nil(activated_or_revoked), do: Decimal.to_integer(activated_or_revoked)
end
