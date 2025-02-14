defmodule Explorer.QueryHelper do
  @moduledoc """
  Helping functions for `Ecto.Query` building.
  """

  import Ecto.Query

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
