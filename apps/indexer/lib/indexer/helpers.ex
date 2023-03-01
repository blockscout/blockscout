defmodule Indexer.Helpers do
  @moduledoc """
  Auxiliary common functions for indexers.
  """

  def is_address_correct?(address) when is_binary(address) do
    String.match?(address, ~r/^0x[[:xdigit:]]{40}$/i)
  end

  def is_address_correct?(_address) do
    false
  end
end
