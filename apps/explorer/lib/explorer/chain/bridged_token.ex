defmodule Explorer.Chain.BridgedToken do
  @moduledoc """
  Represents a bridged token.

  """

  use Explorer.Schema

  import Ecto.Changeset

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      where: 2
    ]

  alias Explorer.{Chain, PagingOptions, Repo}

  alias Explorer.Chain.{
    Address,
    BridgedToken,
    Hash,
    Search,
    Token
  }

  @default_paging_options %PagingOptions{page_size: 50}

  @typedoc """
  * `foreign_chain_id` - chain ID of a foreign token
  * `foreign_token_contract_address_hash` - Foreign token's contract hash
  * `home_token_contract_address` - The `t:Address.t/0` of the home token's contract
  * `home_token_contract_address_hash` - Home token's contract hash foreign key
  * `custom_metadata` - Arbitrary string with custom metadata. For instance, tokens/weights for Balance tokens
  * `custom_cap` - Custom capitalization for this token
  * `lp_token` - Boolean flag: LP token or not
  * `type` - omni/amb
  """
  @type t :: %BridgedToken{
          foreign_chain_id: Decimal.t(),
          foreign_token_contract_address_hash: Hash.Address.t(),
          home_token_contract_address: %Ecto.Association.NotLoaded{} | Address.t(),
          home_token_contract_address_hash: Hash.Address.t(),
          custom_metadata: String.t(),
          custom_cap: Decimal.t(),
          lp_token: boolean(),
          type: String.t(),
          exchange_rate: Decimal.t()
        }

  @derive {Poison.Encoder,
           except: [
             :__meta__,
             :home_token_contract_address,
             :inserted_at,
             :updated_at
           ]}

  @derive {Jason.Encoder,
           except: [
             :__meta__,
             :home_token_contract_address,
             :inserted_at,
             :updated_at
           ]}

  @primary_key false
  schema "bridged_tokens" do
    field(:foreign_chain_id, :decimal)
    field(:foreign_token_contract_address_hash, Hash.Address)
    field(:custom_metadata, :string)
    field(:custom_cap, :decimal)
    field(:lp_token, :boolean)
    field(:type, :string)
    field(:exchange_rate, :decimal)

    belongs_to(
      :home_token_contract_address,
      Token,
      foreign_key: :home_token_contract_address_hash,
      primary_key: true,
      references: :contract_address_hash,
      type: Hash.Address
    )

    timestamps()
  end

  @required_attrs ~w(home_token_contract_address_hash)a
  @optional_attrs ~w(foreign_chain_id foreign_token_contract_address_hash custom_metadata custom_cap boolean type exchange_rate)a

  @doc false
  def changeset(%BridgedToken{} = bridged_token, params \\ %{}) do
    bridged_token
    |> cast(params, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:home_token_contract_address)
    |> unique_constraint(:home_token_contract_address_hash)
  end

  def get_unprocessed_mainnet_lp_tokens_list do
    query =
      from(bt in BridgedToken,
        where: bt.foreign_chain_id == ^1,
        where: is_nil(bt.lp_token) or bt.lp_token == true,
        select: bt
      )

    query
    |> Repo.all()
  end

  defp fetch_top_bridged_tokens(chain_ids, paging_options, filter, sorting, options) do
    bridged_tokens_query =
      __MODULE__
      |> apply_chain_ids_filter(chain_ids)

    base_query =
      from(t in Token.base_token_query(nil, sorting),
        right_join: bt in subquery(bridged_tokens_query),
        on: t.contract_address_hash == bt.home_token_contract_address_hash,
        where: t.total_supply > ^0,
        where: t.bridged,
        select: {t, bt},
        preload: [:contract_address]
      )

    base_query_with_paging =
      base_query
      |> Address.Token.page_tokens(paging_options)
      |> limit(^paging_options.page_size)

    query =
      if filter && filter !== "" do
        case Search.prepare_search_term(filter) do
          {:some, filter_term} ->
            base_query_with_paging
            |> where(fragment("to_tsvector('english', symbol || ' ' || name) @@ to_tsquery(?)", ^filter_term))

          _ ->
            base_query_with_paging
        end
      else
        base_query_with_paging
      end

    query
    |> Chain.select_repo(options).all()
  end

  @spec list_top_bridged_tokens(String.t()) :: [{Token.t(), BridgedToken.t()}]
  def list_top_bridged_tokens(filter, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    chain_ids = Keyword.get(options, :chain_ids, nil)
    sorting = Keyword.get(options, :sorting, [])

    fetch_top_bridged_tokens(chain_ids, paging_options, filter, sorting, options)
  end

  defp apply_chain_ids_filter(query, chain_ids) when chain_ids in [[], nil], do: query

  defp apply_chain_ids_filter(query, chain_ids) when is_list(chain_ids),
    do: from(bt in query, where: bt.foreign_chain_id in ^chain_ids)

  defp translate_destination_to_chain_id(destination) do
    case destination do
      :eth -> 1
      :kovan -> 42
      :bsc -> 56
      :poa -> 99
      nil -> nil
      _ -> :undefined
    end
  end
end
