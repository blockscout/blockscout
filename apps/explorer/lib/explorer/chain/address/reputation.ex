defmodule Explorer.Chain.Address.Reputation do
  @moduledoc """
  This module defines the reputation enum values.
  """
  use Explorer.Schema

  alias Explorer.Chain.Address.ScamBadgeToAddress
  alias Explorer.Chain.Hash
  alias Explorer.Repo

  @enum_values [:ok, :scam]
  def enum_values, do: @enum_values

  @primary_key false
  typed_embedded_schema do
    field(:address_hash, Hash.Address)
    field(:reputation, Ecto.Enum, values: @enum_values)
  end

  def preload_reputation(address_hashes) do
    scam_badges =
      if Application.get_env(:block_scout_web, :hide_scam_addresses) do
        ScamBadgeToAddress
        |> where([sb], sb.address_hash in ^address_hashes)
        |> Repo.all()
        |> Map.new(&{&1.address_hash, &1})
      else
        %{}
      end

    Enum.map(address_hashes, fn address_hash ->
      case Map.get(scam_badges, address_hash) do
        nil -> {address_hash, %__MODULE__{reputation: "ok"}}
        _badge -> {address_hash, %__MODULE__{reputation: "scam"}}
      end
    end)
  end

  def reputation_association do
    [reputation: &__MODULE__.preload_reputation/1]
  end
end

defimpl Jason.Encoder, for: Explorer.Chain.Address.Reputation do
  def encode(reputation, opts) do
    Jason.Encode.string(reputation.reputation, opts)
  end
end
