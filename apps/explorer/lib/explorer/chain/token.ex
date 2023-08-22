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
  alias Explorer.PagingOptions
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
  * `fiat_value` - The price of a token in a configured currency (USD by default).
  * `circulating_market_cap` - The circulating market cap of a token in a configured currency (USD by default).
  * `icon_url` - URL of the token's icon.
  * `is_verified_via_admin_panel` - is token verified via admin panel.
  """
  @type t :: %Token{
          name: String.t(),
          symbol: String.t(),
          total_supply: Decimal.t() | nil,
          decimals: non_neg_integer(),
          type: String.t(),
          cataloged: boolean(),
          contract_address: %Ecto.Association.NotLoaded{} | Address.t(),
          contract_address_hash: Hash.Address.t(),
          holder_count: non_neg_integer() | nil,
          skip_metadata: boolean(),
          total_supply_updated_at_block: non_neg_integer() | nil,
          fiat_value: Decimal.t() | nil,
          circulating_market_cap: Decimal.t() | nil,
          icon_url: String.t(),
          is_verified_via_admin_panel: boolean()
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
    field(:circulating_market_cap, :decimal)
    field(:icon_url, :string)
    field(:is_verified_via_admin_panel, :boolean)

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
  @optional_attrs ~w(cataloged decimals name symbol total_supply skip_metadata total_supply_updated_at_block updated_at fiat_value circulating_market_cap icon_url is_verified_via_admin_panel)a

  @doc false
  def changeset(%Token{} = token, params \\ %{}) do
    token
    |> cast(params, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
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

  def tokens_by_contract_address_hashes(contract_address_hashes) do
    from(token in __MODULE__, where: token.contract_address_hash in ^contract_address_hashes)
  end

  def base_token_query(type, sorting) do
    query = from(t in Token, preload: [:contract_address])

    query |> apply_filter(type) |> apply_sorting(sorting)
  end

  defp apply_filter(query, empty_type) when empty_type in [nil, []], do: query

  defp apply_filter(query, token_types) when is_list(token_types) do
    from(t in query, where: t.type in ^token_types)
  end

  @default_sorting [
    desc_nulls_last: :circulating_market_cap,
    desc_nulls_last: :holder_count,
    asc: :name,
    asc: :contract_address_hash
  ]

  defp apply_sorting(query, sorting) when is_list(sorting) do
    from(t in query, order_by: ^sorting_with_defaults(sorting))
  end

  defp sorting_with_defaults(sorting) when is_list(sorting) do
    (sorting ++ @default_sorting)
    |> Enum.uniq_by(fn {_, field} -> field end)
  end

  def page_tokens(query, paging_options, sorting \\ [])
  def page_tokens(query, %PagingOptions{key: nil}, _sorting), do: query

  def page_tokens(
        query,
        %PagingOptions{
          key: %{} = key
        },
        sorting
      ) do
    dynamic_where = sorting |> sorting_with_defaults() |> do_page_tokens()

    from(token in query,
      where: ^dynamic_where.(key)
    )
  end

  defp do_page_tokens([{order, column} | rest]) do
    fn key -> page_tokens_by_column(key, column, order, do_page_tokens(rest)) end
  end

  defp do_page_tokens([]), do: nil

  defp page_tokens_by_column(%{fiat_value: nil} = key, :fiat_value, :desc_nulls_last, next_column) do
    dynamic(
      [t],
      is_nil(t.fiat_value) and ^next_column.(key)
    )
  end

  defp page_tokens_by_column(%{fiat_value: nil} = key, :fiat_value, :asc_nulls_first, next_column) do
    next_column.(key)
  end

  defp page_tokens_by_column(%{fiat_value: fiat_value} = key, :fiat_value, :desc_nulls_last, next_column) do
    dynamic(
      [t],
      is_nil(t.fiat_value) or t.fiat_value < ^fiat_value or
        (t.fiat_value == ^fiat_value and ^next_column.(key))
    )
  end

  defp page_tokens_by_column(%{fiat_value: fiat_value} = key, :fiat_value, :asc_nulls_first, next_column) do
    dynamic(
      [t],
      not is_nil(t.fiat_value) and
        (t.fiat_value > ^fiat_value or
           (t.fiat_value == ^fiat_value and ^next_column.(key)))
    )
  end

  defp page_tokens_by_column(
         %{circulating_market_cap: nil} = key,
         :circulating_market_cap,
         :desc_nulls_last,
         next_column
       ) do
    dynamic(
      [t],
      is_nil(t.circulating_market_cap) and ^next_column.(key)
    )
  end

  defp page_tokens_by_column(
         %{circulating_market_cap: nil} = key,
         :circulating_market_cap,
         :asc_nulls_first,
         next_column
       ) do
    next_column.(key)
  end

  defp page_tokens_by_column(
         %{circulating_market_cap: circulating_market_cap} = key,
         :circulating_market_cap,
         :desc_nulls_last,
         next_column
       ) do
    dynamic(
      [t],
      is_nil(t.circulating_market_cap) or t.circulating_market_cap < ^circulating_market_cap or
        (t.circulating_market_cap == ^circulating_market_cap and ^next_column.(key))
    )
  end

  defp page_tokens_by_column(
         %{circulating_market_cap: circulating_market_cap} = key,
         :circulating_market_cap,
         :asc_nulls_first,
         next_column
       ) do
    dynamic(
      [t],
      not is_nil(t.circulating_market_cap) and
        (t.circulating_market_cap > ^circulating_market_cap or
           (t.circulating_market_cap == ^circulating_market_cap and ^next_column.(key)))
    )
  end

  defp page_tokens_by_column(%{holder_count: nil} = key, :holder_count, :desc_nulls_last, next_column) do
    dynamic(
      [t],
      is_nil(t.holder_count) and ^next_column.(key)
    )
  end

  defp page_tokens_by_column(%{holder_count: nil} = key, :holder_count, :asc_nulls_first, next_column) do
    next_column.(key)
  end

  defp page_tokens_by_column(%{holder_count: holder_count} = key, :holder_count, :desc_nulls_last, next_column) do
    dynamic(
      [t],
      is_nil(t.holder_count) or t.holder_count < ^holder_count or
        (t.holder_count == ^holder_count and ^next_column.(key))
    )
  end

  defp page_tokens_by_column(%{holder_count: holder_count} = key, :holder_count, :asc_nulls_first, next_column) do
    dynamic(
      [t],
      not is_nil(t.holder_count) and
        (t.holder_count > ^holder_count or
           (t.holder_count == ^holder_count and ^next_column.(key)))
    )
  end

  defp page_tokens_by_column(%{name: nil} = key, :name, :asc, next_column) do
    dynamic(
      [t],
      is_nil(t.name) and ^next_column.(key)
    )
  end

  defp page_tokens_by_column(%{name: name} = key, :name, :asc, next_column) do
    dynamic(
      [t],
      is_nil(t.name) or
        (t.name > ^name or (t.name == ^name and ^next_column.(key)))
    )
  end

  defp page_tokens_by_column(%{contract_address_hash: contract_address_hash}, :contract_address_hash, :asc, nil) do
    dynamic([t], t.contract_address_hash > ^contract_address_hash)
  end
end
