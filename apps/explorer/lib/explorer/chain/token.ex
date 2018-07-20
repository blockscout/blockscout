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
  * `:contract_address` - The `t:Address.t/0` of the token's contract
  * `:contract_address_hash` - Address hash foreign key
  """
  @type t :: %Token{
          name: String.t(),
          symbol: String.t(),
          total_supply: Decimal.t(),
          decimals: non_neg_integer(),
          contract_address: %Ecto.Association.NotLoaded{} | Address.t(),
          contract_address_hash: Hash.Address.t()
        }

  schema "tokens" do
    field(:name, :string)
    field(:symbol, :string)
    field(:total_supply, :decimal)
    field(:decimals, :integer)

    belongs_to(
      :contract_address,
      Address,
      foreign_key: :contract_address_hash,
      references: :hash,
      type: Hash.Address
    )

    timestamps()
  end

  @doc false
  def changeset(%Token{} = token, params \\ %{}) do
    token
    |> cast(params, ~w(name symbol total_supply decimals contract_address_hash)a)
    |> validate_required(~w(contract_address_hash))
    |> foreign_key_constraint(:contract_address)
    |> unique_constraint(:contract_address_hash)
  end
end
