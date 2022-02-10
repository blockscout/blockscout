defmodule UserFromAuth do
  @moduledoc """
  Retrieve the user information from an auth request
  """
  require Logger
  require Poison

  alias Explorer.Accounts.Identity
  alias Explorer.Repo
  alias Ueberauth.Auth

  import Ecto.Query, only: [from: 2]

  def find_or_create(%Auth{} = auth) do
    case find_identity(auth) do
      [] ->
        case create_identity(auth) do
          %{} = basic_info ->
            {:ok, basic_info}

          {:error, changeset} ->
            {:error, changeset}
        end

      [%{} = identity | _] ->
        {:ok, basic_info(auth, identity)}
    end
  end

  defp create_identity(auth) do
    with {:ok, %Identity{} = identity} <- Repo.insert(new_identity(auth)),
         {:ok, _watchlist} <- add_watchlist(identity) do
      basic_info(auth, identity)
    end
  end

  defp new_identity(auth) do
    %Identity{
      uid: auth.uid,
      email: email_from_auth(auth),
      name: name_from_auth(auth)
    }
  end

  defp add_watchlist(identity) do
    watchlist = Ecto.build_assoc(identity, :watchlists, %{})

    with {:ok, _} <- Repo.insert(watchlist),
         do: {:ok, identity}
  end

  defp find_identity(auth) do
    Repo.all(query_identity(auth))
  end

  defp query_identity(auth) do
    from(i in Identity, where: i.uid == ^auth.uid)
  end

  defp basic_info(auth, identity) do
    %{watchlists: [watchlist | _]} = Repo.preload(identity, :watchlists)

    %{
      id: identity.id,
      uid: auth.uid,
      email: email_from_auth(auth),
      name: name_from_auth(auth),
      nickname: nickname_from_auth(auth),
      avatar: avatar_from_auth(auth),
      watchlist_id: watchlist.id
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

  defp name_from_auth(%{info: %{name: name} = info}) do
    if name do
      name
    else
      [info.first_name, info.last_name]
      |> Enum.filter(&(&1 != nil and &1 != ""))
      |> case do
        [] -> info.nickname
        name -> Enum.join(name, " ")
      end
    end
  end
end
