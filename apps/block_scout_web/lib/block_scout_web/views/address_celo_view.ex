defmodule BlockScoutWeb.AddressCeloView do
  use BlockScoutWeb, :view

  def list_with_items?(lst) do
    lst != nil and Ecto.assoc_loaded?(lst) and Enum.count(lst) > 0
  end

  def member_number(-1), do: "Not accepted"

  def member_number(n), do: n

  defp conv(-1), do: 1_000_000
  defp conv(n), do: n

  def sort_members(lst) do
    lst
    |> Enum.sort(fn a, b -> conv(a.member) <= conv(b.member) end)
  end
end
