defmodule Explorer.Chain.Address.Token do
  @moduledoc """
  A projection that represents the relation between a Token and a specific Address.

  This representation is expressed by the following attributes:

  - contract_address_hash - Address of a Token's contract.
  - name - Token's name.
  - symbol - Token's symbol.
  - type - Token's type.
  - decimals - Token's decimals.
  - balance - how much tokens (TokenBalance) the Address has from the Token.
  - transfer_count - a count of how many TokenTransfers of the Token the Address was involved.
  """
  @enforce_keys [:contract_address_hash, :inserted_at, :name, :symbol, :balance, :decimals, :type, :transfers_count]
  defstruct @enforce_keys

  import Ecto.Query
  alias Explorer.{PagingOptions, Chain}

  alias Explorer.Chain.{Hash, Address, Address.TokenBalance}

  @default_paging_options %PagingOptions{page_size: 50}
  @typep paging_options :: {:paging_options, PagingOptions.t()}

  @doc """
  It builds a paginated query of Address.Tokens that have a balance higher than zero ordered by type and name.
  """
  @spec list_address_tokens_with_balance(Hash.t(), [paging_options()]) :: %Ecto.Query{}
  def list_address_tokens_with_balance(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    Chain.Token
    |> Chain.Token.join_with_transfers()
    |> join_with_last_balance(address_hash)
    |> order_filter_and_group(address_hash)
    |> page_tokens(paging_options)
    |> limit(^paging_options.page_size)
  end

  @doc """
  It builds a query of Address.Tokens that have a balance higher to get their count.
  """
  def select_count_address_tokens_with_balance(address_hash) do
    Chain.Token
    |> Chain.Token.join_with_transfers()
    |> join_with_last_balance(address_hash)
    |> order_filter_and_group(address_hash)
    |> select([t], count(t.contract_address_hash))
  end

  defp order_filter_and_group(query, address_hash) do
    from(
      [token, transfer, balance] in query,
      order_by: fragment("? DESC, LOWER(?) ASC NULLS LAST", token.type, token.name),
      where:
        (transfer.to_address_hash == ^address_hash or transfer.from_address_hash == ^address_hash) and balance.value > 0,
      group_by: [token.name, token.symbol, balance.value, token.type, token.contract_address_hash],
      select: %Address.Token{
        contract_address_hash: token.contract_address_hash,
        inserted_at: max(token.inserted_at),
        name: token.name,
        symbol: token.symbol,
        balance: balance.value,
        decimals: max(token.decimals),
        type: token.type,
        transfers_count: count(token.contract_address_hash)
      }
    )
  end

  defp join_with_last_balance(queryable, address_hash) do
    last_balance_query =
      from(
        tb in TokenBalance,
        where: tb.address_hash == ^address_hash,
        distinct: :token_contract_address_hash,
        order_by: [desc: :block_number],
        select: %{value: tb.value, token_contract_address_hash: tb.token_contract_address_hash}
      )

    from(
      t in queryable,
      join: tb in subquery(last_balance_query),
      on: tb.token_contract_address_hash == t.contract_address_hash
    )
  end

  @doc """
  Builds the pagination according to the given key within `PagingOptions`.

  * it just returns the given query when the key is nil.
  * it composes another where clause considering the `type`, `name` and `inserted_at`.

  """
  def page_tokens(query, %PagingOptions{key: nil}), do: query

  def page_tokens(query, %PagingOptions{key: {nil, type, inserted_at}}) do
    where(
      query,
      [token],
      token.type < ^type or (token.type == ^type and is_nil(token.name) and token.inserted_at < ^inserted_at)
    )
  end

  def page_tokens(query, %PagingOptions{key: {name, type, inserted_at}}) do
    upper_name = String.downcase(name)

    where(
      query,
      [token],
      token.type < ^type or
        (token.type == ^type and (fragment("LOWER(?)", token.name) > ^upper_name or is_nil(token.name))) or
        (token.type == ^type and fragment("LOWER(?)", token.name) == ^upper_name and token.inserted_at < ^inserted_at)
    )
  end
end
