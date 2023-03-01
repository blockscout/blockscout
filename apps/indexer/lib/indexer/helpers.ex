defmodule Indexer.Helpers do
  @moduledoc """
  Auxiliary common functions for indexers.
  """

  alias Explorer.Chain.Hash

  def address_hash_to_string(hash) when is_binary(hash) do
    hash
  end

  def address_hash_to_string(hash) do
    Hash.to_string(hash)
  end

  def is_address_correct?(address) when is_binary(address) do
    String.match?(address, ~r/^0x[[:xdigit:]]{40}$/i)
  end

  def is_address_correct?(_address) do
    false
  end
end
