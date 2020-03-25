defmodule BlockScoutWeb.Resolvers.CeloAccount do
  @moduledoc false

  alias Explorer.Chain
  alias Explorer.Chain.{Address, CeloClaims, CeloValidator, CeloValidatorGroup}

  def get_by(_, %{hash: hash}, _) do
    case Chain.get_celo_account(hash) do
      {:error, :not_found} -> {:error, "Celo account not found."}
      {:ok, _} = result -> result
    end
  end

  def get_by(%Address{hash: hash}, _, _) do
    case Chain.get_celo_account(hash) do
      {:error, :not_found} -> {:ok, nil}
      {:ok, _} = result -> result
    end
  end

  def get_by(%CeloValidator{address: hash}, _, _) do
    case Chain.get_celo_account(hash) do
      {:error, :not_found} -> {:ok, nil}
      {:ok, _} = result -> result
    end
  end

  def get_by(%CeloValidatorGroup{address: hash}, _, _) do
    case Chain.get_celo_account(hash) do
      {:error, :not_found} -> {:ok, nil}
      {:ok, _} = result -> result
    end
  end

  def get_by(%CeloClaims{address: hash}, _, _) do
    case Chain.get_celo_claims(hash) do
      {:error, :not_found} -> {:ok, nil}
      {:ok, _} = result -> result
    end
  end
end
