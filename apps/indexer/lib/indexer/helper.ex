defmodule Indexer.Helper do
  @moduledoc """
  Auxiliary common functions for indexers.
  """

  alias Explorer.Chain.Hash

  @spec address_hash_to_string(binary(), boolean()) :: binary()
  def address_hash_to_string(hash, downcase \\ false)

  def address_hash_to_string(hash, downcase) when is_binary(hash) do
    if downcase do
      String.downcase(hash)
    else
      hash
    end
  end

  def address_hash_to_string(hash, downcase) do
    if downcase do
      String.downcase(Hash.to_string(hash))
    else
      Hash.to_string(hash)
    end
  end

  @spec is_address_correct?(binary()) :: boolean()
  def is_address_correct?(address) when is_binary(address) do
    String.match?(address, ~r/^0x[[:xdigit:]]{40}$/i)
  end

  def is_address_correct?(_address) do
    false
  end
end
