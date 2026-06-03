# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Encrypted.Binary do
  @moduledoc false

  use Cloak.Ecto.Binary, vault: Explorer.Vault

  @type t :: binary()
end
