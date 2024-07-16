defmodule Explorer.Encrypted.TransactionHash do
  @moduledoc false

  use Explorer.Encrypted.Types.TransactionHash, vault: Explorer.Vault

  @type t :: Explorer.Chain.Hash.Full.t()
end
