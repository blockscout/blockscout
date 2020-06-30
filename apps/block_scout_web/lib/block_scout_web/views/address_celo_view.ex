defmodule BlockScoutWeb.AddressCeloView do
  use BlockScoutWeb, :view

  def list_with_items?(lst) do
    lst != nil and Ecto.assoc_loaded?(lst) and Enum.count(lst) > 0
  end

  def format_pending_votes(member) do
    format_according_to_decimals(member.pending.value, Decimal.new(18))
  end

  def compute_active_votes(%{units: nil}) do
    Decimal.new(0)
  end

  def compute_active_votes(%{group: %{units: nil}}) do
    Decimal.new(0)
  end

  def compute_active_votes(member) do
    units = member.units.value
    total_units = member.group.total_units.value
    total_active = member.group.active_votes.value
    Decimal.div_int(Decimal.mult(units, total_active), total_units)
  end

  def format_active_votes(member) do
    format_according_to_decimals(compute_active_votes(member), Decimal.new(18))
  end

  def compute_locked_gold(address) do
    non_locked = address.celo_account.nonvoting_locked_gold.value

    votes =
      if list_with_items?(address.celo_voted) do
        Enum.reduce(address.celo_voted, Decimal.new(0), fn member, votes ->
          Decimal.add(votes, Decimal.add(member.pending.value, compute_active_votes(member)))
        end)
      else
        Decimal.new(0)
      end

    result = Decimal.add(non_locked, votes)
    format_according_to_decimals(result, Decimal.new(18))
  end

  def member_number(-1), do: "Not accepted"

  def member_number(n), do: n

  defp conv(-1), do: 1_000_000
  defp conv(n), do: n

  def sort_members(lst) do
    lst
    |> Enum.sort(fn a, b -> conv(a.member) <= conv(b.member) end)
  end

  def sort_voters(lst) do
    lst
    |> Enum.filter(fn a -> a.total.value > Decimal.new(0) end)
    |> Enum.sort(fn a, b -> a.total.value >= b.total.value end)
  end
end
