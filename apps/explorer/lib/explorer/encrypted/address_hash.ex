defmodule Explorer.Encrypted.AddressHash do
  @moduledoc false

  use Explorer.Encrypted.Types.AddressHash, vault: Explorer.Vault

  @type t :: Explorer.Chain.Hash.Address.t()
end
