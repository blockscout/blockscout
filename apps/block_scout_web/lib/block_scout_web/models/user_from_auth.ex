defmodule BlockScoutWeb.Models.UserFromAuth do
  @moduledoc """
  Retrieve the user information from an auth request
  """
  require Logger
  require Poison

  alias Explorer.Account.Identity
  alias Explorer.Repo
  alias Ueberauth.Auth

  import Ecto.Query, only: [from: 2]

  def find_or_create(%Auth{} = auth) do
    case find_identity(auth) do
      [] ->
        case create_identity(auth) do
          %Identity{} = identity ->
            {:ok, session_info(auth, identity)}

          {:error, changeset} ->
            {:error, changeset}
        end

      [%{} = identity | _] ->
        update_identity(identity, update_identity_map(auth))
        {:ok, session_info(auth, identity)}
    end
  end

  defp create_identity(auth) do
    with {:ok, %Identity{} = identity} <- Repo.account_repo().insert(new_identity(auth)),
         {:ok, _watchlist} <- add_watchlist(identity) do
      identity
    end
  end

  defp update_identity(identity, attrs) do
    identity
    |> Identity.changeset(attrs)
    |> Repo.account_repo().update()
  end

  defp new_identity(auth) do
    %Identity{
      uid: auth.uid,
      uid_hash: auth.uid,
      email: email_from_auth(auth),
      name: name_from_auth(auth),
      nickname: nickname_from_auth(auth),
      avatar: avatar_from_auth(auth)
    }
  end

  defp add_watchlist(identity) do
    watchlist = Ecto.build_assoc(identity, :watchlists, %{})

    with {:ok, _} <- Repo.account_repo().insert(watchlist),
         do: {:ok, identity}
  end

  def find_identity(auth_or_uid) do
    Repo.account_repo().all(query_identity(auth_or_uid))
  end

  def query_identity(%Auth{} = auth) do
    from(i in Identity, where: i.uid_hash == ^auth.uid)
  end

  def query_identity(id) do
    from(i in Identity, where: i.id == ^id)
  end

  defp session_info(
         %Auth{extra: %Ueberauth.Auth.Extra{raw_info: %{user: %{"email_verified" => false}}}} = auth,
         identity
       ) do
    %{
      id: identity.id,
      uid: auth.uid,
      email: email_from_auth(auth),
      email_verified: false
    }
  end

  defp session_info(auth, identity) do
    %{watchlists: [watchlist | _]} = Repo.account_repo().preload(identity, :watchlists)

    %{
      id: identity.id,
      uid: auth.uid,
      email: email_from_auth(auth),
      name: name_from_auth(auth),
      nickname: nickname_from_auth(auth),
      avatar: avatar_from_auth(auth),
      watchlist_id: watchlist.id,
      email_verified: true
    }
  end

  defp update_identity_map(auth) do
    %{
      email: email_from_auth(auth),
      name: name_from_auth(auth),
      nickname: nickname_from_auth(auth),
      avatar: avatar_from_auth(auth)
    }
  end

  # github does it this way
  defp avatar_from_auth(%{info: %{urls: %{avatar_url: image}}}), do: image

  # facebook does it this way
  defp avatar_from_auth(%{info: %{image: image}}), do: image

  # default case if nothing matches
  defp avatar_from_auth(auth) do
    Logger.warn(auth.provider <> " needs to find an avatar URL!")
    Logger.debug(Poison.encode!(auth))
    nil
  end

  defp email_from_auth(%{info: %{email: email}}), do: email

  defp nickname_from_auth(%{info: %{nickname: nickname}}), do: nickname

  defp name_from_auth(%{info: %{name: name}})
       when name != "" and not is_nil(name),
       do: name

  defp name_from_auth(%{info: info}) do
    [info.first_name, info.last_name, info.nickname]
    |> Enum.map(&(&1 |> to_string() |> String.trim()))
    |> case do
      ["", "", nick] -> nick
      ["", lastname, _] -> lastname
      [name, "", _] -> name
      [name, lastname, _] -> name <> " " <> lastname
    end
  end
end
