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
  alias Ueberauth.Auth.{Extra, Info}

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
    field(:name, :string, virtual: true)
    field(:nickname, :string, virtual: true)
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
    |> cast(attrs, [:uid, :email, :name, :nickname, :avatar, :verification_email_sent_at, :otp_sent_at])
    |> validate_required([:uid])
    |> put_hashed_fields()
  end

  defp put_hashed_fields(changeset) do
    # Using force_change instead of put_change due to https://github.com/danielberkompas/cloak_ecto/issues/53
    changeset
    |> force_change(:uid_hash, get_field(changeset, :uid))
  end

  @doc """
  Populates Identity virtual fields with data from user-stored session.

  This function updates the virtual fields of an Identity struct with
  information from the user's session.

  ## Parameters
  - `identity`: The Identity struct to be updated.
  - `session`: A map containing session information.

  ## Returns
  - An updated Identity struct with populated virtual fields.
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

  @doc """
  Finds an existing Identity or creates a new one based on authentication data.

  This function attempts to find an Identity matching the given authentication
  data. If not found, it creates a new Identity.

  ## Parameters
  - `auth`: An Auth struct containing authentication information.

  ## Returns
  - `{:ok, session()}`: A tuple containing the atom `:ok` and a session map if
    the Identity is found or successfully created.
  - `{:error, Ecto.Changeset.t()}`: A tuple containing the atom `:error` and a
    changeset if there was an error creating the Identity.
  """
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

  @doc """
  Finds an Identity based on authentication data or ID.

  This function searches for an Identity using either authentication data or
  an ID.

  ## Parameters
  - `auth_or_uid`: Either an Auth struct or an integer ID.

  ## Returns
  - The found Identity struct or nil if not found.
  """
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

  @doc """
  Finds multiple Identities based on a list of user IDs.

  This function retrieves multiple Identity structs that match the given list
  of user IDs.

  ## Parameters
  - `user_ids`: A list of user ID strings.

  ## Returns
  - A list of found Identity structs.
  """
  @spec find_identities([String.t()]) :: [t()]
  def find_identities(user_ids) do
    Repo.account_repo().all(query_identities(user_ids))
  end

  defp query_identities(user_ids) do
    from(i in __MODULE__, where: i.uid_hash in ^user_ids)
  end

  @doc """
  Deletes multiple Identities as part of a Multi transaction.

  This function adds a step to a Multi transaction to delete Identities with
  the specified IDs.

  ## Parameters
  - `multi`: The Multi struct to which the delete operation will be added.
  - `ids_to_merge`: A list of Identity IDs to be deleted.

  ## Returns
  - An updated Multi struct with the delete operation added.
  """
  @spec delete(Multi.t(), [integer()]) :: Multi.t()
  def delete(multi, ids_to_merge) do
    Multi.run(multi, :delete_identities, fn repo, _ ->
      query = from(identity in __MODULE__, where: identity.id in ^ids_to_merge)
      {:ok, repo.delete_all(query)}
    end)
  end

  @doc """
  Adds an operation to acquire and lock an account identity record in the database.

  This operation performs a SELECT FOR UPDATE on the identity record, which prevents
  concurrent modifications of the record until the transaction is committed or rolled
  back.

  ## Parameters
  - `multi`: An Ecto.Multi struct representing a series of database operations
  - `identity_id`: The ID of the account identity to lock

  ## Returns
  - An updated Ecto.Multi struct with the `:acquire_identity` operation added. The
    operation will return:
    - `{:ok, identity}` if the identity is found and locked successfully
    - `{:error, :not_found}` if no identity exists with the given ID
  """
  @spec acquire_with_lock(Multi.t(), integer()) :: Multi.t()
  def acquire_with_lock(multi, identity_id) do
    Multi.run(multi, :acquire_identity, fn repo, _ ->
      identity_query = from(identity in __MODULE__, where: identity.id == ^identity_id, lock: "FOR UPDATE")

      case repo.one(identity_query) do
        nil ->
          {:error, :not_found}

        identity ->
          {:ok, identity}
      end
    end)
  end

  defp session_info(auth, identity) do
    if email_verified_from_auth(auth) do
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
    else
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

  defp email_from_auth(%Auth{extra: %Extra{raw_info: %{user: %{"user_metadata" => %{"email" => email}}}}}),
    do: email

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

  @doc """
  Extracts the address hash from authentication data.

  This function attempts to extract an Ethereum address hash from the
  authentication data, either from user metadata or by parsing the UID.

  ## Parameters
  - `auth`: An Auth struct containing authentication information.

  ## Returns
  - A string representation of the Ethereum address hash, or nil if not found.
  """
  @spec address_hash_from_auth(Auth.t()) :: String.t() | nil
  def address_hash_from_auth(%Auth{
        extra: %Extra{raw_info: %{user: %{"user_metadata" => %{"web3_address_hash" => address_hash}}}}
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

  defp email_verified_from_auth(%Auth{extra: %Extra{raw_info: %{user: %{"user_metadata" => %{"email" => _email}}}}}),
    do: true

  defp email_verified_from_auth(%Auth{extra: %Extra{raw_info: %{user: %{"email_verified" => false}}}}), do: false
  defp email_verified_from_auth(_), do: true
end
