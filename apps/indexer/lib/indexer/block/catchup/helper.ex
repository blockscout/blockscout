defmodule Indexer.Block.Catchup.Helper do
  @moduledoc """
  Catchup helper functions
  """

  def sanitize_ranges(ranges) do
    ranges
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.sort_by(
      fn
        from.._to -> from
        el -> el
      end,
      :asc
    )
    |> Enum.chunk_while(
      nil,
      fn
        _from.._to = chunk, nil ->
          {:cont, chunk}

        _ch_from..ch_to = chunk, acc_from..acc_to = acc ->
          if Range.disjoint?(chunk, acc),
            do: {:cont, acc, chunk},
            else: {:cont, acc_from..max(ch_to, acc_to)}

        num, nil ->
          {:halt, num}

        num, acc_from.._ = acc ->
          if Range.disjoint?(num..num, acc), do: {:cont, acc, num}, else: {:halt, acc_from}

        _, num ->
          {:halt, num}
      end,
      fn reminder -> {:cont, reminder, nil} end
    )
  end
end
