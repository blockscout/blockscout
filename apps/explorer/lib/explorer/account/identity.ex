defmodule Explorer.Account.Identity do
  @moduledoc """
    Identity of user fetched via Oauth
  """
  use Explorer.Schema

  require Logger
  require Poison

  alias BlockScoutWeb.Chain
  alias Ecto.Multi
  alias Explorer.Account.Api.Plan
  alias Explorer.Account.{TagAddress, Watchlist}
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash}
  alias Ueberauth.Auth
  alias Ueberauth.Auth.Info

  @type session :: %{
          optional(:name) => String.t(),
          optional(:watchlist_id) => integer(),
          id: integer(),
          uid: String.t(),
          email: String.t(),
          nickname: String.t(),
          avatar: String.t(),
          address_hash: String.t(),
          email_verified: boolean()
        }

  typed_schema "account_identities" do
    field(:uid_hash, Cloak.Ecto.SHA256) :: binary() | nil
    field(:uid, Explorer.Encrypted.Binary, null: false)
    field(:email, Explorer.Encrypted.Binary, null: false)
    field(:name, Explorer.Encrypted.Binary, virtual: true)
    field(:nickname, Explorer.Encrypted.Binary, virtual: true)
    field(:address_hash, Hash.Address, virtual: true)
    field(:avatar, Explorer.Encrypted.Binary)
    field(:verification_email_sent_at, :utc_datetime_usec)
    field(:otp_sent_at, :utc_datetime_usec)

    has_many(:tag_addresses, TagAddress)
    has_many(:watchlists, Watchlist)

    belongs_to(:plan, Plan)

    timestamps()
  end

  @doc false
  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:uid, :email, :name, :nickname, :avatar, :verification_email_sent_at])
    |> validate_required([:uid, :email, :name])
    |> put_hashed_fields()
  end

  defp put_hashed_fields(changeset) do
    # Using force_change instead of put_change due to https://github.com/danielberkompas/cloak_ecto/issues/53
    changeset
    |> force_change(:uid_hash, get_field(changeset, :uid))
  end

  @doc """
  Populate Identity virtual fields with data from user-stored session.
  """
  @spec put_session_info(t(), session()) :: t()
  def put_session_info(identity, %{name: name, nickname: nickname, address_hash: address_hash}) do
    %__MODULE__{
      identity
      | name: name,
        nickname: nickname,
        address_hash: address_hash
    }
  end

  def put_session_info(identity, %{name: name, nickname: nickname}) do
    %__MODULE__{
      identity
      | name: name,
        nickname: nickname
    }
  end

  @spec find_or_create(Auth.t()) :: {:ok, session()} | {:error, Ecto.Changeset.t()}
  def find_or_create(%Auth{} = auth) do
    case find_identity(auth) do
      nil ->
        case create_identity(auth) do
          %__MODULE__{} = identity ->
            {:ok, session_info(auth, identity)}

          {:error, changeset} ->
            {:error, changeset}
        end

      %{} = identity ->
        update_identity(identity, update_identity_map(auth))
        {:ok, session_info(auth, identity)}
    end
  end

  defp create_identity(auth) do
    with {:ok, %__MODULE__{} = identity} <- Repo.account_repo().insert(new_identity(auth)),
         {:ok, _watchlist} <- add_watchlist(identity) do
      identity
    end
  end

  defp update_identity(identity, attrs) do
    identity
    |> changeset(attrs)
    |> Repo.account_repo().update()
  end

  defp new_identity(auth) do
    %__MODULE__{
      uid: auth.uid,
      uid_hash: auth.uid,
      email: email_from_auth(auth),
      name: name_from_auth(auth),
      nickname: nickname_from_auth(auth),
      avatar: avatar_from_auth(auth),
      address_hash: address_hash_from_auth(auth)
    }
  end

  defp add_watchlist(identity) do
    watchlist = Ecto.build_assoc(identity, :watchlists, %{})

    with {:ok, _} <- Repo.account_repo().insert(watchlist),
         do: {:ok, identity}
  end

  @spec find_identity(Auth.t() | integer()) :: t() | nil
  def find_identity(auth_or_uid) do
    Repo.account_repo().one(query_identity(auth_or_uid))
  end

  defp query_identity(%Auth{} = auth) do
    from(i in __MODULE__, where: i.uid_hash == ^auth.uid)
  end

  defp query_identity(id) do
    from(i in __MODULE__, where: i.id == ^id)
  end

  @spec find_identities([String.t()]) :: [t()]
  def find_identities(user_ids) do
    Repo.account_repo().all(query_identities(user_ids))
  end

  defp query_identities(user_ids) do
    from(i in __MODULE__, where: i.uid_hash in ^user_ids)
  end

  @spec delete(Multi.t(), [integer()]) :: Multi.t()
  def delete(multi, ids_to_merge) do
    Multi.run(multi, :delete_identities, fn repo, _ ->
      query = from(identity in __MODULE__, where: identity.id in ^ids_to_merge)
      {:ok, repo.delete_all(query)}
    end)
  end

  defp session_info(
         %Auth{extra: %Ueberauth.Auth.Extra{raw_info: %{user: %{"email_verified" => false}}}} = auth,
         identity
       ) do
    %{
      id: identity.id,
      uid: auth.uid,
      email: email_from_auth(auth),
      nickname: nickname_from_auth(auth),
      avatar: avatar_from_auth(auth),
      address_hash: address_hash_from_auth(auth),
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
      address_hash: address_hash_from_auth(auth),
      watchlist_id: watchlist.id,
      email_verified: true
    }
  end

  defp update_identity_map(auth) do
    %{
      email: email_from_auth(auth),
      name: name_from_auth(auth),
      nickname: nickname_from_auth(auth),
      avatar: avatar_from_auth(auth),
      address_hash: address_hash_from_auth(auth)
    }
  end

  # github does it this way
  defp avatar_from_auth(%{info: %{urls: %{avatar_url: image}}}), do: image

  # facebook does it this way
  defp avatar_from_auth(%{info: %{image: image}}), do: image

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

  @spec address_hash_from_auth(Auth.t()) :: String.t() | nil
  def address_hash_from_auth(%Auth{
        extra: %Ueberauth.Auth.Extra{raw_info: %{user: %{"user_metadata" => %{"web3_address_hash" => address_hash}}}}
      }) do
    address_hash
  end

  def address_hash_from_auth(%Auth{uid: uid, info: %Info{nickname: nickname}}) do
    case uid |> String.slice(-42..-1) |> Chain.string_to_address_hash() do
      {:ok, address_hash} ->
        address_hash |> Address.checksum()

      _ ->
        case String.contains?(uid, "Passkey") && Chain.string_to_address_hash(nickname) do
          {:ok, address_hash} -> address_hash |> Address.checksum()
          _ -> nil
        end
    end
  end
end
