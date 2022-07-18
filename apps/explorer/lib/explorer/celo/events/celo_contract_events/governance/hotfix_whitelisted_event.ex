defmodule Explorer.Celo.ContractEvents.Governance.HotfixWhitelistedEvent do
  @moduledoc """
  Struct modelling the HotfixWhitelisted event from the Governance Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "HotfixWhitelisted",
    topic: "0xf6d22d0b43a6753880b8f9511b82b86cd0fe349cd580bbe6a25b6dc063ef496f"

  event_param(:hash, {:bytes, 32}, :indexed)
  event_param(:whitelister, :address, :unindexed)
end
