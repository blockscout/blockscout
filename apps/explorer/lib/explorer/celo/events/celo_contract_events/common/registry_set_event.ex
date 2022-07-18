defmodule Explorer.Celo.ContractEvents.Common.RegistrySetEvent do
  @moduledoc """
  Struct modelling the RegistrySet event from the Exchange, Epochrewards, Stabletoken, Attestations, Doublesigningslasher, Escrow, Governanceslasher, Gaspriceminimum, Transferwhitelist, Reserve, Accounts, Exchangebrl, Downtimeslasher, Election, Goldtoken, Lockedgold, Governance, Validators, Exchangeeur, Grandamento, Stabletokenbrl, Stabletokeneur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "RegistrySet",
    topic: "0x27fe5f0c1c3b1ed427cc63d0f05759ffdecf9aec9e18d31ef366fc8a6cb5dc3b"

  event_param(:registry_address, :address, :indexed)
end
