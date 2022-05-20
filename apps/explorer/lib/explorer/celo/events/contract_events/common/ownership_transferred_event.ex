defmodule Explorer.Celo.ContractEvents.Common.OwnershipTransferredEvent do
  @moduledoc """
  Struct modelling the OwnershipTransferred event from the Exchange, Epochrewards, Stabletoken, Attestations, Doublesigningslasher, Escrow, Governanceslasher, Gaspriceminimum, Registry, Transferwhitelist, Feecurrencywhitelist, Freezer, Reserve, Accounts, Exchangebrl, Blockchainparameters, Downtimeslasher, Election, Goldtoken, Lockedgold, Governance, Validators, Sortedoracles, Exchangeeur, Grandamento, Random, Stabletokenbrl, Stabletokeneur Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "OwnershipTransferred",
    topic: "0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0"

  event_param(:previous_owner, :address, :indexed)
  event_param(:new_owner, :address, :indexed)
end
