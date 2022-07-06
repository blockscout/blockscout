defmodule Explorer.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: Explorer.Vault
end
