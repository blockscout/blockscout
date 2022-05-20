defmodule Explorer.Celo.ContractEvents.Common.ImplementationSetEvent do
  @moduledoc """
  Struct modelling the ImplementationSet event from the Exchangeproxy, Epochrewardsproxy, Freezerproxy, Validatorsproxy, Stabletokeneurproxy, Stabletokenbrlproxy, Feecurrencywhitelistproxy, Lockedgoldproxy, Doublesigningslasherproxy, Blockchainparametersproxy, Downtimeslasherproxy, Accountsproxy, Gaspriceminimumproxy, Attestationsproxy, Randomproxy, Escrowproxy, Electionproxy, Governanceslasherproxy, Sortedoraclesproxy, Goldtokenproxy, Exchangebrlproxy, Exchangeeurproxy, Stabletokenproxy, Governanceproxy, Reserveproxy, Grandamentoproxy Celo core contracts.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "ImplementationSet",
    topic: "0xab64f92ab780ecbf4f3866f57cee465ff36c89450dcce20237ca7a8d81fb7d13"

  event_param(:implementation, :address, :indexed)
end
