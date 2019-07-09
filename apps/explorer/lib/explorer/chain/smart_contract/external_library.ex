defmodule Explorer.Chain.SmartContract.ExternalLibrary do
  use Ecto.Schema

  embedded_schema do
    field :name
    field :address_hash
  end
end
