defmodule Explorer.Chain.SmartContract.ExternalLibrary do
  @moduledoc """
  The representation of an external library that was used for a smart contract.
  """

  use Ecto.Schema

  embedded_schema do
    field(:name)
    field(:address_hash)
  end
end
