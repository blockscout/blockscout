defmodule Explorer.Chain.ExchangeRate do
  @moduledoc """
  Data type and schema for storing exchange rates for tokens.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @typedoc """
  * `address` - address of the validator.
  * 
  """

  @type t :: %__MODULE__{
          token: Hash.Address.t(),
          rate: float
        }

  schema "exchange_rates" do
    field(:rate, :float)

    belongs_to(
      :token_address,
      Address,
      foreign_key: :token,
      references: :hash,
      type: Hash.Address
    )
  end
end
