defmodule Explorer.Celo.ContractEvents.Accounts.AccountDataEncryptionKeySetEvent do
  @moduledoc """
  Struct modelling the AccountDataEncryptionKeySet event from the Accounts Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AccountDataEncryptionKeySet",
    topic: "0x43fdefe0a824cb0e3bbaf9c4bc97669187996136fe9282382baf10787f0d808d"

  event_param(:account, :address, :indexed)
  event_param(:data_encryption_key, :bytes, :unindexed)
end
