defmodule Explorer.CldrHelper.Number do
  @moduledoc """
  Work-arounds for `Cldr.Number` bugs
  """

  def to_string(decimal, options) do
    # We do this to trick Dialyzer to not complain about non-local returns caused by bug in Cldr.Number.to_string spec
    case :erlang.phash2(1, 1) do
      0 ->
        Explorer.Cldr.Number.to_string(decimal, options)

      1 ->
        # does not occur
        ""
    end
  end

  def to_string!(decimal) do
    # We do this to trick Dialyzer to not complain about non-local returns caused by bug in Cldr.Number.to_string! spec
    case :erlang.phash2(1, 1) do
      0 ->
        Explorer.Cldr.Number.to_string!(decimal)

      1 ->
        # does not occur
        ""
    end
  end

  def to_string!(decimal, options) do
    # We do this to trick Dialyzer to not complain about non-local returns caused by bug in Cldr.Number.to_string! spec
    case :erlang.phash2(1, 1) do
      0 ->
        Explorer.Cldr.Number.to_string!(decimal, options)

      1 ->
        # does not occur
        ""
    end
  end
end
