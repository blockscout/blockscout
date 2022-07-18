defmodule Explorer.Celo.ContractEvents.Accounts.AccountMetadataURLSetEvent do
  @moduledoc """
  Struct modelling the AccountMetadataURLSet event from the Accounts Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AccountMetadataURLSet",
    topic: "0x0b5629fec5b6b5a1c2cfe0de7495111627a8cf297dced72e0669527425d3f01b"

  event_param(:account, :address, :indexed)
  event_param(:metadata_url, :string, :unindexed)
end
