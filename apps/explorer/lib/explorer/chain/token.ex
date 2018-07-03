defmodule Explorer.Chain.Token do
  @moduledoc """
  Represents an ERC-20 token.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Explorer.Chain.{Address, Hash, Token}

  @typedoc """
  * `:name` - Name of the token
  * `:symbol` - Trading symbol of the token
  * `:total_supply` - The total supply of the token
  * `:decimals` - Number of decimal places the token can be subdivided to
  * `:owner_address` - The `t:Address.t/0` of the owning wallet
  * `:owner_address_hash` - Address hash foreign key
  * `:contract_address` - The `t:Address.t/0` of the token's contract
  * `:contract_address_hash` - Address hash foreign key
  """
  @type t :: %Token{
          name: String.t(),
          symbol: String.t(),
          total_supply: non_neg_integer(),
          decimals: non_neg_integer(),
          owner_address: Ecto.Association.NotLoaded.t() | Address.t(),
          owner_address_hash: Hash.Truncated.t(),
          contract_address: Ecto.Association.NotLoaded.t() | Address.t(),
          contract_address_hash: Hash.Truncated.t()
        }

  schema "tokens" do
    field(:name, :string)
    field(:symbol, :string)
    field(:total_supply, :integer)
    field(:decimals, :integer)

    belongs_to(
      :owner_address,
      Address,
      foreign_key: :owner_address_hash,
      references: :hash,
      type: Hash.Truncated
    )

    belongs_to(
      :contract_address,
      Address,
      foreign_key: :contract_address_hash,
      references: :hash,
      type: Hash.Truncated
    )
  end

  @doc false
  def changeset(%Token{} = token, params \\ %{}) do
    token
    |> cast(params, ~w(name symbol total_supply decimals owner_address_hash contract_address_hash)a)
    |> assoc_constraint(:owner_address)
    |> assoc_constraint(:contract_address)
    |> unique_constraint(:contract_address_hash)
  end
end
