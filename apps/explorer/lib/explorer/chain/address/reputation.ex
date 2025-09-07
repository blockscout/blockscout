defmodule Explorer.Chain.Address.Reputation do
  @moduledoc """
  This module defines the reputation enum values.
  """

  @enum_values [:ok, :scam]
  def enum_values, do: @enum_values
end
