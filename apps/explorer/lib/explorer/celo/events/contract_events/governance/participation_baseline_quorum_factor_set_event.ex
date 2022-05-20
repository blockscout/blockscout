defmodule Explorer.Celo.ContractEvents.Governance.ParticipationBaselineQuorumFactorSetEvent do
  @moduledoc """
  Struct modelling the ParticipationBaselineQuorumFactorSet event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ParticipationBaselineQuorumFactorSet",
    topic: "0xddfdbe55eaaa70fe2b8bc82a9b0734c25cabe7cb6f1457f9644019f0b5ff91fc"

  event_param(:baseline_quorum_factor, {:uint, 256}, :unindexed)
end
