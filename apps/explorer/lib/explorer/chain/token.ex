defmodule Explorer.Chain.Token do
  @moduledoc """
  Represents a token.

  ## Token Indexing

  The following types of tokens are indexed:

  * ERC-20
  * ERC-721

  ## Token Specifications

  * [ERC-20](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md)
  * [ERC-721](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md)
  * [ERC-777](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-777.md)
  * [ERC-1155](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1155.md)
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Explorer.Chain.{Address, Hash, Token}

  @typedoc """
  * `:name` - Name of the token
  * `:symbol` - Trading symbol of the token
  * `:total_supply` - The total supply of the token
  * `:decimals` - Number of decimal places the token can be subdivided to
  * `:type` - Type of token
  * `:calatoged` - Flag for if token information has been cataloged
  * `:contract_address` - The `t:Address.t/0` of the token's contract
  * `:contract_address_hash` - Address hash foreign key
  """
  @type t :: %Token{
          name: String.t(),
          symbol: String.t(),
          total_supply: Decimal.t(),
          decimals: non_neg_integer(),
          type: String.t(),
          cataloged: boolean(),
          contract_address: %Ecto.Association.NotLoaded{} | Address.t(),
          contract_address_hash: Hash.Address.t()
        }

  @primary_key false
  schema "tokens" do
    field(:name, :string)
    field(:symbol, :string)
    field(:total_supply, :decimal)
    field(:decimals, :integer)
    field(:type, :string)
    field(:cataloged, :boolean)

    belongs_to(
      :contract_address,
      Address,
      foreign_key: :contract_address_hash,
      references: :hash,
      type: Hash.Address
    )

    timestamps()
  end

  @required_attrs ~w(contract_address_hash type)a
  @optional_attrs ~w(cataloged decimals name symbol total_supply)a

  @doc false
  def changeset(%Token{} = token, params \\ %{}) do
    token
    |> cast(params, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:contract_address)
    |> unique_constraint(:contract_address_hash)
  end
end
