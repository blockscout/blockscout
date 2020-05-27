defmodule BlockScoutWeb.Resolvers.CeloAccount do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.{Address, CeloAccount, CeloClaims, CeloValidator, CeloValidatorGroup}

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

  def get_claims(_, %{hash: hash}, _) do
    {:ok, Chain.get_celo_claims(hash)}
  end

  def get_claims(%{address: hash}, _, _) do
    {:ok, Chain.get_celo_claims(hash)}
  end

  def get_voted(%CeloAccount{address: hash}, args, _) do
    hash
    |> GraphQL.account_voted_query()
    |> Connection.from_query(&Repo.all/1, args, [])
  end
end
