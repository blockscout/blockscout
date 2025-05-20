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
end
