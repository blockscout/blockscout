defmodule Explorer.Celo.ContractEvents.Common.OwnerSetEvent do
  @moduledoc """
  Struct modelling the OwnerSet event from the Exchangeproxy, Epochrewardsproxy, Freezerproxy, Validatorsproxy, Stabletokeneurproxy, Stabletokenbrlproxy, Feecurrencywhitelistproxy, Lockedgoldproxy, Doublesigningslasherproxy, Blockchainparametersproxy, Downtimeslasherproxy, Accountsproxy, Gaspriceminimumproxy, Attestationsproxy, Randomproxy, Escrowproxy, Electionproxy, Governanceslasherproxy, Sortedoraclesproxy, Goldtokenproxy, Exchangebrlproxy, Exchangeeurproxy, Stabletokenproxy, Governanceproxy, Reserveproxy, Grandamentoproxy Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "OwnerSet",
    topic: "0x50146d0e3c60aa1d17a70635b05494f864e86144a2201275021014fbf08bafe2"

  event_param(:owner, :address, :indexed)
end
