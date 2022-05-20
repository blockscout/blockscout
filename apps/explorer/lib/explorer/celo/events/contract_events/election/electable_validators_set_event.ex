defmodule Explorer.Celo.ContractEvents.Election.ElectableValidatorsSetEvent do
  @moduledoc """
  Struct modelling the ElectableValidatorsSet event from the Election Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ElectableValidatorsSet",
    topic: "0xb3ae64819ff89f6136eb58b8563cb32c6550f17eaf97f9ecc32f23783229f6de"

  event_param(:min, {:uint, 256}, :unindexed)
  event_param(:max, {:uint, 256}, :unindexed)
end
