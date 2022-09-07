defmodule Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent do
  @moduledoc """
  Struct modelling the Election.ValidatorGroupVoteActivated event

  ValidatorGroupVoteActivated(
      address indexed account,
      address indexed group,
      uint256 value,
      uint256 units
    );
  """

  alias Explorer.Celo.ContractEvents.Common
  alias Explorer.Chain.CeloContractEvent
  alias Explorer.Repo

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorGroupVoteActivated",
    topic: "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe"

  event_param(:account, :address, :indexed)
  event_param(:group, :address, :indexed)
  event_param(:value, {:uint, 256}, :unindexed)
  event_param(:units, {:uint, 256}, :unindexed)

  def get_account_group_pairs_with_activated_votes(block_number) do
    query =
      from(
        event in CeloContractEvent,
        where: event.name == "ValidatorGroupVoteActivated",
        where: event.block_number < ^block_number,
        group_by: [json_extract_path(event.params, ["account"]), json_extract_path(event.params, ["group"])],
        select: %{
          account_hash: json_extract_path(event.params, ["account"]),
          group_hash: json_extract_path(event.params, ["group"])
        }
      )

    query
    |> Repo.all(timeout: :infinity)
    |> Enum.map(&%{account_hash: Common.ca(&1.account_hash), group_hash: Common.ca(&1.group_hash)})
  end
end
