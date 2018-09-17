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

  import Ecto.{Changeset, Query}
  alias Explorer.PagingOptions
  alias Explorer.Chain.{Address, Hash, Token, TokenTransfer}
  alias Explorer.Chain.Address.TokenBalance

  @default_paging_options %PagingOptions{page_size: 50}

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

  @typep paging_options :: {:paging_options, PagingOptions.t()}

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

  @doc """
  Builds an `Ecto.Query` to fetch tokens that the given address has interacted with
  along with the latest balance of each token for that address and the count of
  transfers the address had with each token

  warning: tokens with a latest balance of zero will be ignored

  In order to fetch a token, the given address must have transfered tokens to or received tokens
  from another address. This quey orders by the token type and name.
  """
  @spec with_transfers_by_address(Hash.t(), [paging_options()]) :: %Ecto.Query{}
  def with_transfers_by_address(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    query =
      from(
        tb in TokenBalance,
        where: tb.address_hash == ^address_hash,
        distinct: :token_contract_address_hash,
        order_by: [desc: :block_number],
        select: %{value: tb.value, token_contract_address_hash: tb.token_contract_address_hash}
      )

    query
    |> with_last_balance_and_transfers_count(address_hash)
    |> page_token(paging_options)
    |> limit(^paging_options.page_size)
  end

  defp with_last_balance_and_transfers_count(last_balance_query, address_hash) do
    from(
      t in Token,
      join: tt in TokenTransfer,
      on: tt.token_contract_address_hash == t.contract_address_hash,
      join: tb in subquery(last_balance_query),
      on: tb.token_contract_address_hash == t.contract_address_hash,
      order_by: [desc: t.type, asc: fragment("UPPER(?)", t.name)],
      where: (tt.to_address_hash == ^address_hash or tt.from_address_hash == ^address_hash) and tb.value > 0,
      group_by: [t.name, t.symbol, tb.value, t.type, t.contract_address_hash],
      select: %{
        contract_address_hash: t.contract_address_hash,
        inserted_at: max(t.inserted_at),
        name: t.name,
        symbol: t.symbol,
        value: tb.value,
        decimals: max(t.decimals),
        type: t.type,
        transfers: count(t.name)
      }
    )
  end

  @doc """
  adds to the passed `Ecto.Query` a criteria indicating the first token of the current page
  returns the original query if the received `PagingOptions` has a nil value for the key attribute
  """
  def page_token(query, %PagingOptions{key: nil}), do: query

  def page_token(query, %PagingOptions{key: {name, type, inserted_at}}) do
    upper_name = String.upcase(name)

    where(
      query,
      [token],
      token.type < ^type or (token.type == ^type and fragment("UPPER(?)", token.name) > ^upper_name) or
        (token.type == ^type and fragment("UPPER(?)", token.name) == ^upper_name and token.inserted_at < ^inserted_at)
    )
  end
end
