defmodule Explorer.Etherscan do
  @moduledoc """
  The etherscan context.
  """

  import Ecto.Query, only: [from: 2, where: 3]

  alias Explorer.{Repo, Chain}
  alias Explorer.Chain.{Hash, Transaction}

  @default_options %{
    order_by_direction: :asc,
    page_number: 1,
    page_size: 10_000,
    start_block: nil,
    end_block: nil
  }

  @doc """
  Returns the maximum allowed page size number.

  """
  @spec page_size_max :: pos_integer()
  def page_size_max do
    @default_options.page_size
  end

  @doc """
  Gets a list of transactions for a given `t:Explorer.Chain.Hash.Address`.

  """
  @spec list_transactions(Hash.Address.t()) :: [map()]
  def list_transactions(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash,
        options \\ @default_options
      ) do
    case Chain.max_block_number() do
      {:ok, max_block_number} ->
        merged_options = Map.merge(@default_options, options)
        list_transactions(address_hash, max_block_number, merged_options)

      _ ->
        []
    end
  end

  @transaction_fields [
    :block_hash,
    :block_number,
    :created_contract_address_hash,
    :cumulative_gas_used,
    :from_address_hash,
    :gas,
    :gas_price,
    :gas_used,
    :hash,
    :index,
    :input,
    :nonce,
    :status,
    :to_address_hash,
    :value
  ]

  defp list_transactions(address_hash, max_block_number, options) do
    query =
      from(
        t in Transaction,
        inner_join: b in assoc(t, :block),
        where: t.to_address_hash == ^address_hash,
        or_where: t.from_address_hash == ^address_hash,
        or_where: t.created_contract_address_hash == ^address_hash,
        order_by: [{^options.order_by_direction, t.block_number}],
        limit: ^options.page_size,
        offset: ^offset(options),
        select:
          merge(map(t, ^@transaction_fields), %{
            block_timestamp: b.timestamp,
            confirmations: fragment("? - ?", ^max_block_number, t.block_number)
          })
      )

    query
    |> where_start_block_match(options)
    |> where_end_block_match(options)
    |> Repo.all()
  end

  defp where_start_block_match(query, %{start_block: nil}), do: query

  defp where_start_block_match(query, %{start_block: start_block}) do
    where(query, [t], t.block_number >= ^start_block)
  end

  defp where_end_block_match(query, %{end_block: nil}), do: query

  defp where_end_block_match(query, %{end_block: end_block}) do
    where(query, [t], t.block_number <= ^end_block)
  end

  defp offset(options), do: (options.page_number - 1) * options.page_size
end
