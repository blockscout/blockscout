defmodule Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent do
  @moduledoc """
  Struct modelling the Validators.ValidatorEpochPaymentDistributed event

  ValidatorEpochPaymentDistributed(
        address indexed validator,
        uint256 validatorPayment,
        address indexed group,
        uint256 groupPayment
    );
  """

  alias Explorer.Celo.ContractEvents.Common
  alias Explorer.Chain.CeloContractEvent
  alias Explorer.Repo

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorEpochPaymentDistributed",
    topic: "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975"

  event_param(:validator, :address, :indexed)
  event_param(:group, :address, :indexed)
  event_param(:validator_payment, {:uint, 256}, :unindexed)
  event_param(:group_payment, {:uint, 256}, :unindexed)

  def get_validator_and_group_rewards_for_block(block_number) do
    query =
      from(event in CeloContractEvent,
        select: %{
          group: json_extract_path(event.params, ["group"]),
          group_payment: json_extract_path(event.params, ["group_payment"]),
          validator: json_extract_path(event.params, ["validator"]),
          validator_payment: json_extract_path(event.params, ["validator_payment"])
        },
        where: event.block_number == ^block_number,
        where: event.name == "ValidatorEpochPaymentDistributed"
      )

    query
    |> Repo.all()
    |> Enum.map(&Map.merge(&1, %{group: Common.ca(&1.group), validator: Common.ca(&1.validator)}))
  end
end
