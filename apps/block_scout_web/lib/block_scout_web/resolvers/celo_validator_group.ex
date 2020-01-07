defmodule BlockScoutWeb.Resolvers.CeloValidatorGroup do
  @moduledoc false

  alias Explorer.Chain
  alias Explorer.Chain.{Address, CeloAccount, CeloValidator}

  def get_by(_, %{hash: hash}, _) do
    case Chain.get_celo_validator_group(hash) do
      {:error, :not_found} -> {:error, "Celo validator group not found."}
      {:ok, _} = result -> result
    end
  end

  def get_by(%Address{hash: hash}, _, _) do
    case Chain.get_celo_validator_group(hash) do
      {:error, :not_found} -> {:ok, nil}
      {:ok, _} = result -> result
    end
  end

  def get_by(%CeloAccount{address: hash}, _, _) do
    case Chain.get_celo_validator_group(hash) do
      {:error, :not_found} -> {:ok, nil}
      {:ok, _} = result -> result
    end
  end

  def get_by(%CeloValidator{group_address_hash: hash}, _, _) do
    case Chain.get_celo_validator_group(hash) do
      {:error, :not_found} -> {:ok, nil}
      {:ok, _} = result -> result
    end
  end

  def get_by(_, _, _) do
    case Chain.get_celo_validator_groups() do
      {:error, :not_found} -> {:error, "Celo validator group query failed."}
      {:ok, _} = result -> result
    end
  end
end
