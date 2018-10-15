defmodule Explorer.Admin do
  @moduledoc """
  Context for performing administrative tasks.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Explorer.{Accounts, Repo}
  alias Explorer.Accounts.User
  alias Explorer.Admin.{Administrator, Recovery}

  @doc """
  Fetches the owner of the explorer.
  """
  @spec owner :: {:ok, Administrator.t()} | {:error, :not_found}
  def owner do
    query =
      from(a in Administrator,
        where: a.role == "owner",
        preload: [:user]
      )

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      admin ->
        {:ok, admin}
    end
  end

  @doc """
  Retrieves an admin record from a user
  """
  def from_user(%User{id: user_id}) do
    query =
      from(a in Administrator,
        where: a.user_id == ^user_id
      )

    case Repo.one(query) do
      %Administrator{} = admin ->
        {:ok, admin}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Registers a new user as an administrator with the `owner` role.
  """
  @spec register_owner(map()) :: {:ok, %{user: User.t(), admin: Administrator.t()}} | {:error, Changeset.t()}
  def register_owner(params) do
    Repo.transaction(fn ->
      with {:ok, user} <- Accounts.register_new_account(params),
           {:ok, admin} <- promote_user(user, "owner") do
        %{admin: admin, user: user}
      else
        {:error, error} ->
          Repo.rollback(error)
      end
    end)
  end

  defp promote_user(%User{id: user_id}, role) do
    %Administrator{}
    |> Administrator.changeset(%{user_id: user_id, role: role})
    |> Repo.insert()
  end

  def recovery_key do
    Recovery.key(Recovery)
  end
end
