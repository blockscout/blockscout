defmodule Explorer.Celo.ContractEvents.Validators.ValidatorScoreUpdatedEvent do
  @moduledoc """
  Struct modelling the ValidatorScoreUpdated event from the Validators Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ValidatorScoreUpdated",
    topic: "0xedf9f87e50e10c533bf3ae7f5a7894ae66c23e6cbbe8773d7765d20ad6f995e9"

  event_param(:validator, :address, :indexed)
  event_param(:score, {:uint, 256}, :unindexed)
  event_param(:epoch_score, {:uint, 256}, :unindexed)
end
