defmodule Explorer.Accounts do
  @moduledoc """
  Entrypoint for modifying user account information.
  """

  alias Ecto.Changeset
  alias Explorer.Accounts.{User}
  alias Explorer.Accounts.User.Registration
  alias Explorer.Repo

  @doc """
  Registers a new user account.
  """
  @spec register_new_account(map()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def register_new_account(params) do
    registration_changeset = Registration.changeset(params)

    with {:registration_valid?, true} <- {:registration_valid?, registration_changeset.valid?},
         {:ok, user} <- do_register_new_account(registration_changeset) do
      {:ok, user}
    else
      {:registration_valid?, false} ->
        {:error, registration_changeset}

      {:error, %Changeset{} = user_changeset} ->
        {:error, %Changeset{registration_changeset | errors: user_changeset.errors, valid?: false}}
    end
  end

  @spec do_register_new_account(Changeset.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  defp do_register_new_account(%Changeset{changes: changes}) do
    new_user_params = %{
      username: changes.username,
      password: changes.password,
      contacts: [
        %{
          email: changes.email,
          primary: true
        }
      ]
    }

    %User{}
    |> User.changeset(new_user_params)
    |> Repo.insert()
  end
end
