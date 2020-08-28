defmodule BlockScoutWeb.Resolvers.Address do
  @moduledoc false

  alias Explorer.Chain
  alias Explorer.Chain.{CeloAccount, CeloValidator, CeloValidatorGroup}

  def get_by(_, %{hashes: hashes}, _) do
    case Chain.hashes_to_addresses(hashes) do
      [] -> {:error, "Addresses not found."}
      result -> {:ok, result}
    end
  end

  def get_by(_, %{block_number: num}, _) do
    case Chain.get_elected_validators(num) do
      [] -> {:error, "Addresses not found."}
      result -> {:ok, result}
    end
  end

  def get_by(_, %{hash: hash}, _) do
    case Chain.hash_to_address(hash) do
      {:error, :not_found} -> {:error, "Address not found."}
      {:ok, _} = result -> result
    end
  end

  def get_by(%CeloAccount{address: hash}, _, _) do
    case Chain.hash_to_address(hash) do
      {:error, :not_found} -> {:error, "Address not found."}
      {:ok, _} = result -> result
    end
  end

  def get_by(%CeloValidator{address: hash}, _, _) do
    case Chain.hash_to_address(hash) do
      {:error, :not_found} -> {:error, "Address not found."}
      {:ok, _} = result -> result
    end
  end

  def get_by(%CeloValidatorGroup{address: hash}, _, _) do
    case Chain.hash_to_address(hash) do
      {:error, :not_found} -> {:error, "Address not found."}
      {:ok, _} = result -> result
    end
  end
end
