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
end
