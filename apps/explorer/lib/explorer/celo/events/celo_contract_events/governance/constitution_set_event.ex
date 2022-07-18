defmodule Explorer.Celo.ContractEvents.Governance.ConstitutionSetEvent do
  @moduledoc """
  Struct modelling the ConstitutionSet event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ConstitutionSet",
    topic: "0x60c5b4756af49d7b071b00dbf0f87af605cce11896ecd3b760d19f0f9d3fbcef"

  event_param(:destination, :address, :indexed)
  event_param(:function_id, {:bytes, 4}, :indexed)
  event_param(:threshold, {:uint, 256}, :unindexed)
end
