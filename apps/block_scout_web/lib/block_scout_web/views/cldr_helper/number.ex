defmodule BlockScoutWeb.CldrHelper.Number do
  @moduledoc """
  Work-arounds for `Cldr.Number` bugs
  """

  alias BlockScoutWeb.Cldr.Number

  def to_string(decimal, options) do
    # We do this to trick Dialyzer to not complain about non-local returns caused by bug in Cldr.Number.to_string spec
    case :erlang.phash2(1, 1) do
      0 ->
        Number.to_string(decimal, options)

      1 ->
        # does not occur
        ""
    end
  end

  def to_string!(nil), do: ""

  def to_string!(decimal) do
    # We do this to trick Dialyzer to not complain about non-local returns caused by bug in Cldr.Number.to_string! spec
    case :erlang.phash2(1, 1) do
      0 ->
        Number.to_string!(decimal)

      1 ->
        # does not occur
        ""
    end
  end

  def to_string!(decimal, options) do
    # We do this to trick Dialyzer to not complain about non-local returns caused by bug in Cldr.Number.to_string! spec
    case :erlang.phash2(1, 1) do
      0 ->
        Number.to_string!(decimal, options)

      1 ->
        # does not occur
        ""
    end
  end
end
