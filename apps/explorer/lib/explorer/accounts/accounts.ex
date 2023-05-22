defmodule Explorer.Accounts do
  @moduledoc """
  Entrypoint for modifying user account information.
  """

  alias Bcrypt
  alias Ecto.Changeset
  alias Explorer.Accounts.User
  alias Explorer.Accounts.User.{Authenticate, Registration}
  alias Explorer.Repo

  @doc """
  Registers a new user account.
  """
  @spec register_new_account(map()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def register_new_account(params) do
    registration =
      params
      |> Registration.changeset()
      |> Changeset.apply_action(:insert)

    with {:registration, {:ok, registration}} <- {:registration, registration},
         {:ok, user} <- do_register_new_account(registration) do
      {:ok, user}
    else
      {:registration, {:error, _} = error} ->
        error

      {:error, %Changeset{}} = error ->
        error
    end
  end

  @spec do_register_new_account(Registration.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  defp do_register_new_account(%Registration{} = registration) do
    new_user_params = %{
      username: registration.username,
      password: registration.password,
      contacts: [
        %{
          email: registration.email,
          primary: true
        }
      ]
    }

    %User{}
    |> User.changeset(new_user_params)
    |> Repo.insert()
  end

  @doc """
  Authenticates a user from a map of authentication params.
  """
  @spec authenticate(map()) :: {:ok, User.t()} | {:error, :invalid_credentials | Changeset.t()}
  def authenticate(user_params) when is_map(user_params) do
    authentication =
      user_params
      |> Authenticate.changeset()
      |> Changeset.apply_action(:insert)

    with {:ok, authentication} <- authentication,
         {:user, %User{} = user} <- {:user, Repo.get_by(User, username: authentication.username)},
         {:password, true} <- {:password, Bcrypt.verify_pass(authentication.password, user.password_hash)} do
      {:ok, user}
    else
      {:error, %Changeset{}} = error ->
        error

      {:user, nil} ->
        # Run dummy check to mitigate timing attacks
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      {:password, false} ->
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Fetches a user by id.
  """
  @spec fetch_user(integer()) :: {:ok, User.t()} | {:error, :not_found}
  def fetch_user(user_id) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end
end
