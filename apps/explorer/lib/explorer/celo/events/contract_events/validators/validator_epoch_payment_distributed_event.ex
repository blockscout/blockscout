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

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorEpochPaymentDistributed",
    topic: "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975"

  event_param(:validator, :address, :indexed)
  event_param(:group, :address, :indexed)
  event_param(:validator_payment, {:uint, 256}, :unindexed)
  event_param(:group_payment, {:uint, 256}, :unindexed)
end
