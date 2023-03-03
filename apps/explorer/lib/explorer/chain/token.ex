defmodule Explorer.Chain.Token do
  @moduledoc """
  Represents a token.

  ## Token Indexing

  The following types of tokens are indexed:

  * ERC-20
  * ERC-721
  * ERC-1155

  ## Token Specifications

  * [ERC-20](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md)
  * [ERC-721](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md)
  * [ERC-777](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-777.md)
  * [ERC-1155](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1155.md)
  """

  use Explorer.Schema

  import Ecto.{Changeset, Query}

  alias Ecto.Changeset
  alias Explorer.Chain.{Address, Hash, Token}
  alias Explorer.SmartContract.Helper

  @typedoc """
  * `name` - Name of the token
  * `symbol` - Trading symbol of the token
  * `total_supply` - The total supply of the token
  * `decimals` - Number of decimal places the token can be subdivided to
  * `type` - Type of token
  * `cataloged` - Flag for if token information has been cataloged
  * `contract_address` - The `t:Address.t/0` of the token's contract
  * `contract_address_hash` - Address hash foreign key
  * `holder_count` - the number of `t:Explorer.Chain.Address.t/0` (except the burn address) that have a
    `t:Explorer.Chain.CurrentTokenBalance.t/0` `value > 0`.  Can be `nil` when data not migrated.
  """
  @type t :: %Token{
          name: String.t(),
          symbol: String.t(),
          total_supply: Decimal.t(),
          decimals: non_neg_integer(),
          type: String.t(),
          cataloged: boolean(),
          contract_address: %Ecto.Association.NotLoaded{} | Address.t(),
          contract_address_hash: Hash.Address.t(),
          holder_count: non_neg_integer() | nil,
          skip_metadata: boolean(),
          total_supply_updated_at_block: non_neg_integer() | nil,
          fiat_value: Decimal.t() | nil,
          market_cap: Decimal.t() | nil
        }

  @derive {Poison.Encoder,
           except: [
             :__meta__,
             :contract_address,
             :inserted_at,
             :updated_at
           ]}

  @derive {Jason.Encoder,
           except: [
             :__meta__,
             :contract_address,
             :inserted_at,
             :updated_at
           ]}

  @primary_key false
  schema "tokens" do
    field(:name, :string)
    field(:symbol, :string)
    field(:total_supply, :decimal)
    field(:decimals, :decimal)
    field(:type, :string)
    field(:cataloged, :boolean)
    field(:holder_count, :integer)
    field(:skip_metadata, :boolean)
    field(:total_supply_updated_at_block, :integer)
    field(:fiat_value, :decimal)
    field(:market_cap, :decimal)

    belongs_to(
      :contract_address,
      Address,
      foreign_key: :contract_address_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Address
    )

    timestamps()
  end

  @required_attrs ~w(contract_address_hash type)a
  @optional_attrs ~w(cataloged decimals name symbol total_supply skip_metadata total_supply_updated_at_block fiat_value market_cap)a

  @doc false
  def changeset(%Token{} = token, params \\ %{}) do
    token
    |> cast(params, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:contract_address)
    |> trim_name()
    |> sanitize_token_input(:name)
    |> sanitize_token_input(:symbol)
    |> unique_constraint(:contract_address_hash)
  end

  defp trim_name(%Changeset{valid?: false} = changeset), do: changeset

  defp trim_name(%Changeset{valid?: true} = changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, String.trim(name))
    end
  end

  defp sanitize_token_input(%Changeset{valid?: false} = changeset, _), do: changeset

  defp sanitize_token_input(%Changeset{valid?: true} = changeset, key) do
    case get_change(changeset, key) do
      nil ->
        changeset

      property ->
        put_change(changeset, key, Helper.sanitize_input(property))
    end
  end

  @doc """
  Builds an `Ecto.Query` to fetch the cataloged tokens.

  These are tokens with cataloged field set to true and updated_at is earlier or equal than an hour ago.
  """
  def cataloged_tokens(minutes \\ 2880) do
    date_now = DateTime.utc_now()
    some_time_ago_date = DateTime.add(date_now, -:timer.minutes(minutes), :millisecond)

    from(
      token in __MODULE__,
      select: token.contract_address_hash,
      where: token.cataloged == true and token.updated_at <= ^some_time_ago_date
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch a `batch_size` number of the tokens,
  possibly starting from `last_updated_address_hash` ordered by `contract_address_hash`.
  """
  def tokens_to_update_fiat_value(nil, batch_size) do
    from(
      token in __MODULE__,
      order_by: token.contract_address_hash,
      limit: ^batch_size
    )
  end

  def tokens_to_update_fiat_value(last_updated_address_hash, batch_size) do
    from(
      token in __MODULE__,
      order_by: token.contract_address_hash,
      where: token.contract_address_hash > ^last_updated_address_hash,
      limit: ^batch_size
    )
  end
end
