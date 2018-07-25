defmodule Indexer.BoundInterval do
  @moduledoc """
  An interval for `Process.send_after` that is restricted to being between a `minimum` and `maximum` value
  """

  @enforce_keys ~w(maximum)a
  defstruct minimum: 1,
            current: 1,
            maximum: nil

  def within(minimum..maximum) when is_integer(minimum) and is_integer(maximum) and minimum <= maximum do
    %__MODULE__{minimum: minimum, current: minimum, maximum: maximum}
  end

  def decrease(%__MODULE__{minimum: minimum, current: current} = bound_interval)
      when is_integer(minimum) and is_integer(current) do
    new_current =
      current
      |> div(2)
      |> max(minimum)

    %__MODULE__{bound_interval | current: new_current}
  end

  def increase(%__MODULE__{current: current, maximum: maximum} = bound_interval)
      when is_integer(current) and is_integer(maximum) do
    new_current = min(current * 2, maximum)

    %__MODULE__{bound_interval | current: new_current}
  end
end
