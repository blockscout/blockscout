# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.QueryHelper do
  @moduledoc """
  Helping functions for `Ecto.Query` building.
  """

  import Ecto.Query

  @doc """
  Generates a fragment for multi column filtering.

  ## Example

  This clause
  `where: ^QueryHelper.tuple_in([:address_hash, :token_contract_address_hash, :token_id], ids)`
  will be transformed to such SQL:
  `WHERE (address_hash, token_contract_address_hash, token_id) IN ((*hash_bytes*, *hash_bytes*, *token_id*), ...)`
  """
  @spec tuple_in([atom()], [any()]) :: any()
  def tuple_in(_fields, []), do: false

  # sobelow_skip ["RCE.CodeModule"]
  def tuple_in(fields, values) do
    fields = Enum.map(fields, &quote(do: field(x, unquote(&1))))
    values = for v <- values, do: quote(do: fragment("(?)", splice(^unquote(Macro.escape(Tuple.to_list(v))))))
    field_params = Enum.map_join(fields, ",", fn _ -> "?" end)
    value_params = Enum.map_join(values, ",", fn _ -> "?" end)
    pattern = "(#{field_params}) in (#{value_params})"

    dynamic_quote =
      quote do
        dynamic(
          [x],
          fragment(unquote(pattern), unquote_splicing(fields), unquote_splicing(values))
        )
      end

    dynamic_quote
    |> Code.eval_quoted()
    |> elem(0)
  end

  @doc """
  A macro generating a fragment that selects CTID column.

  CTID - is a system column representing the physical location
  of the row version within its table.

  The macro is supposed to be used in `SELECT FOR UPDATE` part of update and delete statements
  where corresponding rows are locked before modification in order to prevent deadlocks
  (see docs: sharelock.md). Should be used along with `join_on_ctid/2`.

  ## Example

  ```
    ordered_query =
      from(table in Table,
        select: select_ctid(table),
        # Enforce Table ShareLocks order
        order_by: [
          table.column_1,
          table.column_2,
        ],
        lock: "FOR UPDATE"
      )

    query =
      from(table in Table,
        inner_join: ordered_table in subquery(ordered_query),
        on: join_on_ctid(table, ordered_table)
      )
    Repo.delete_all(query)
  ```

  Will be transformed to such SQL:
  ```
    DELETE
    FROM "table" AS t0 USING (SELECT st0."ctid" AS "ctid"
                              FROM "table" AS st0
                              ORDER BY st0."column_1", st0."column_2" FOR UPDATE) AS s1
    WHERE (t0."ctid" = s1."ctid");
  ```
  """
  defmacro select_ctid(table_binding) do
    quote do
      %{ctid: fragment(~s(?."ctid"), unquote(table_binding))}
    end
  end

  @doc """
  A macro generating a fragment that joins 2 tables on CTID column.

  It is supposed to be used as an `:on` option for joins.
  See `select_ctid/1` for more details on usage.
  """
  defmacro join_on_ctid(first_table_binding, second_table_binding) do
    quote do
      fragment(~s(?."ctid" = ?."ctid"), unquote(first_table_binding), unquote(second_table_binding))
    end
  end

  @doc """
  Returns the cardinality of `association` on the schema `queryable` selects from.

  `:unknown` when the schema cannot be resolved — a query built on a subquery or
  a raw source — or when it declares no such association.
  """
  @spec association_cardinality(Ecto.Queryable.t(), atom()) :: :one | :many | :unknown
  def association_cardinality(queryable, association) do
    case association_reflection(queryable, association) do
      %{cardinality: cardinality} -> cardinality
      _ -> :unknown
    end
  end

  @doc """
  Whether `association` can be fetched through a join and preloaded from it.

  `Ecto.Repo.Assoc` maps joined rows back onto their parents by the related
  schema's primary key and raises `Ecto.NoPrimaryKeyFieldError` without one, and
  a `through` association's reflection does not even name a related schema.
  Neither can come from a join.
  """
  @spec join_preloadable?(Ecto.Queryable.t(), atom()) :: boolean()
  def join_preloadable?(queryable, association) do
    with %{related: related} <- association_reflection(queryable, association),
         schema when not is_nil(schema) <- ecto_schema(related) do
      schema.__schema__(:primary_key) != []
    else
      _ -> false
    end
  end

  @doc """
  Whether `query` already carries `association` as a named binding or a
  join-preload, in which case joining it again collides on the `as:` alias.
  """
  @spec association_bound?(Ecto.Queryable.t(), atom()) :: boolean()
  def association_bound?(%Ecto.Query{assocs: assocs} = query, association),
    do: has_named_binding?(query, association) or List.keymember?(assocs, association, 0)

  def association_bound?(_queryable, _association), do: false

  @doc """
  Returns the association reflection `association` resolves to on `queryable`,
  or `nil` when either the schema or the association cannot be resolved.
  """
  @spec association_reflection(Ecto.Queryable.t(), atom()) :: struct() | nil
  def association_reflection(queryable, association) do
    with schema when not is_nil(schema) <- query_schema(queryable),
         %{} = reflection <- schema.__schema__(:association, association) do
      reflection
    else
      _ -> nil
    end
  end

  @doc """
  Returns the Ecto schema `queryable` selects from, or `nil` when it selects from
  a subquery, a raw source, or anything that is not a schema.
  """
  @spec query_schema(Ecto.Queryable.t()) :: module() | nil
  def query_schema(%Ecto.Query{from: %{source: {_source, schema}}}), do: ecto_schema(schema)
  def query_schema(queryable), do: ecto_schema(queryable)

  defp ecto_schema(module) when is_atom(module) and not is_nil(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 2), do: module
  end

  defp ecto_schema(_module), do: nil
end
