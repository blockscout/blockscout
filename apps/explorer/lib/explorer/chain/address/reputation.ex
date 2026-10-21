# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Address.Reputation do
  @moduledoc """
  This module defines the reputation enum values.
  """
  use Explorer.Schema

  alias Explorer.Chain.Cache.ScamAddresses
  alias Explorer.Chain.Hash

  @enum_values [:ok, :scam]
  def enum_values, do: @enum_values

  @primary_key false
  typed_embedded_schema do
    field(:address_hash, Hash.Address)
    field(:reputation, Ecto.Enum, values: @enum_values)
  end

  def preload_reputation(address_hashes) do
    scam_hashes =
      if Application.get_env(:block_scout_web, :hide_scam_addresses) do
        ScamAddresses.scam_hashes(address_hashes)
      else
        MapSet.new()
      end

    Enum.map(address_hashes, fn address_hash ->
      if MapSet.member?(scam_hashes, address_hash) do
        {address_hash, %__MODULE__{reputation: "scam"}}
      else
        {address_hash, %__MODULE__{reputation: "ok"}}
      end
    end)
  end

  def reputation_association do
    [reputation: &__MODULE__.preload_reputation/1]
  end
end

defimpl JSON.Encoder, for: Explorer.Chain.Address.Reputation do
  def encode(reputation, encoder) do
    JSON.Encoder.encode(reputation.reputation, encoder)
  end
end
