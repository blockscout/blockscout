defmodule Explorer.Account.PublicTagsRequest do
  @moduledoc """
    Module is responsible for requests for public tags
  """
  use Explorer.Schema

  alias Ecto.{Changeset, Multi}
  alias Explorer.Account.Identity
  alias Explorer.Chain.Hash
  alias Explorer.{Helper, Repo}
  alias Explorer.ThirdPartyIntegrations.AirTable

  import Ecto.Changeset

  @distance_between_same_addresses 24 * 3600

  @max_public_tags_request_per_account 15
  @max_addresses_per_request 10
  @max_tags_per_request 2
  @max_tag_length 35

  @user_not_found "User not found"

  typed_schema "account_public_tags_requests" do
    field(:company, :string)
    field(:website, :string)
    field(:tags, :string, null: false)
    field(:addresses, {:array, Hash.Address}, null: false)
    field(:description, :string)
    field(:additional_comment, :string, null: false)
    field(:request_type, :string, null: false)
    field(:is_owner, :boolean, default: true, null: false)
    field(:remove_reason, :string)
    field(:request_id, :string)
    field(:full_name, Explorer.Encrypted.Binary, null: false)
    field(:email, Explorer.Encrypted.Binary, null: false)

    belongs_to(:identity, Identity, null: false)

    timestamps()
  end

  @local_fields [:__meta__, :inserted_at, :updated_at, :id, :request_id]

  def to_map(%__MODULE__{} = request) do
    association_fields = request.__struct__.__schema__(:associations)
    waste_fields = association_fields ++ @local_fields

    network = Helper.get_app_host() <> Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:path]

    request |> Map.from_struct() |> Map.drop(waste_fields) |> Map.put(:network, network)
  end

  @attrs ~w(company website description remove_reason request_id)a
  @required_attrs ~w(full_name email tags addresses additional_comment request_type is_owner identity_id)a

  def changeset(%__MODULE__{} = public_tags_request, attrs \\ %{}) do
    public_tags_request
    |> cast(trim_empty_addresses(attrs), @attrs ++ @required_attrs)
    |> validate_tags()
    |> validate_required(@required_attrs, message: "Required")
    |> validate_format(:email, ~r/^[A-Z0-9._%+-]+@[A-Z0-9-]+.+.[A-Z]{2,4}$/i, message: "is invalid")
    |> validate_length(:addresses, min: 1, max: @max_addresses_per_request)
    |> extract_and_validate_addresses()
    |> foreign_key_constraint(:identity_id, message: @user_not_found)
    |> public_tags_request_count_constraint()
    |> public_tags_request_time_interval_uniqueness()
  end

  def changeset_without_constraints(%__MODULE__{} = public_tags_request \\ %__MODULE__{}, attrs \\ %{}) do
    public_tags_request
    |> cast(attrs, @attrs ++ @required_attrs)
  end

  @doc """
  Creates a new public tags request within a database transaction.

  The creation process involves verifying the existence of the associated identity
  and ensuring data consistency through a database lock. The transaction prevents
  concurrent modifications of the same identity record.

  ## Parameters
  - `attrs`: Map containing the following fields:
    - `:identity_id`: Required. The ID of the identity associated with the request
    - `:company`: Optional. The company name
    - `:website`: Optional. The company's website
    - `:tags`: Required. The requested tags
    - `:addresses`: Required. List of blockchain addresses
    - `:description`: Optional. Description of the request
    - `:additional_comment`: Required. Additional information about the request
    - `:request_type`: Required. The type of the request
    - `:is_owner`: Optional. Boolean indicating ownership (defaults to true)
    - `:remove_reason`: Optional. Reason for tag removal if applicable
    - `:request_id`: Optional. External request identifier
    - `:full_name`: Required. Encrypted full name of the requester
    - `:email`: Required. Encrypted email of the requester

  ## Returns
  - `{:ok, public_tags_request}` - Returns the created public tags request
  - `{:error, changeset}` - Returns a changeset with errors if:
    - The identity doesn't exist
    - The provided data is invalid
    - Required fields are missing
  """
  @spec create(map()) :: {:ok, t()} | {:error, Changeset.t()}
  def create(%{identity_id: identity_id} = attrs) do
    Multi.new()
    |> Identity.acquire_with_lock(identity_id)
    |> Multi.insert(:public_tags_request, fn _ ->
      %__MODULE__{}
      |> changeset(Map.put(attrs, :request_type, "add"))
    end)
    |> Repo.account_repo().transaction()
    |> case do
      {:ok, %{public_tags_request: public_tags_request}} ->
        {:ok, public_tags_request} |> AirTable.submit()

      {:error, :acquire_identity, :not_found, _changes} ->
        {:error,
         %__MODULE__{}
         |> changeset(Map.put(attrs, :request_type, "add"))
         |> add_error(:identity_id, @user_not_found,
           constraint: :foreign,
           constraint_name: "account_public_tags_requests_identity_id_fkey"
         )}
    end
  end

  def create(attrs) do
    {:error,
     %__MODULE__{}
     |> changeset(Map.put(attrs, :request_type, "add"))}
  end

  defp trim_empty_addresses(%{addresses: addresses} = attrs) when is_list(addresses) do
    filtered_addresses = Enum.filter(addresses, fn addr -> addr != "" and !is_nil(addr) end)
    Map.put(attrs, :addresses, if(filtered_addresses == [], do: [""], else: filtered_addresses))
  end

  defp trim_empty_addresses(attrs), do: attrs

  def public_tags_request_count_constraint(%Changeset{changes: %{identity_id: identity_id}} = request) do
    if identity_id
       |> public_tags_requests_by_identity_id_query()
       |> limit(@max_public_tags_request_per_account)
       |> Repo.account_repo().aggregate(:count, :id) >= @max_public_tags_request_per_account do
      request
      |> add_error(:tags, "Max #{@max_public_tags_request_per_account} public tags requests per account")
    else
      request
    end
  end

  def public_tags_request_count_constraint(changeset), do: changeset

  defp public_tags_request_time_interval_uniqueness(%Changeset{changes: %{addresses: addresses}} = request) do
    prepared_addresses =
      if request.data && request.data.addresses, do: addresses -- request.data.addresses, else: addresses

    public_tags_request =
      request
      |> fetch_field!(:identity_id)
      |> public_tags_requests_by_identity_id_query()
      |> where(
        [public_tags_request],
        fragment("? && ?", public_tags_request.addresses, ^Enum.map(prepared_addresses, fn x -> x.bytes end))
      )
      |> limit(1)
      |> Repo.account_repo().one()

    now = DateTime.utc_now()

    if !is_nil(public_tags_request) &&
         public_tags_request.inserted_at
         |> DateTime.add(@distance_between_same_addresses, :second)
         |> DateTime.compare(now) == :gt do
      request
      |> add_error(:addresses, "You have already submitted the same public tag address in the last 24 hours")
    else
      request
    end
  end

  defp public_tags_request_time_interval_uniqueness(changeset), do: changeset

  defp extract_and_validate_addresses(%Changeset{} = changeset) do
    with {:fetch, {_src, addresses}} <- {:fetch, fetch_field(changeset, :addresses)},
         false <- is_nil(addresses),
         {:uniqueness, true} <- {:uniqueness, Enum.count(Enum.uniq(addresses)) == Enum.count(addresses)} do
      changeset
    else
      {:uniqueness, false} ->
        add_error(changeset, :addresses, "All addresses should be unique")

      _ ->
        add_error(changeset, :addresses, "No addresses")
    end
  end

  defp validate_tags(%Changeset{} = changeset) do
    with {:fetch, {_src, tags}} <- {:fetch, fetch_field(changeset, :tags)},
         false <- is_nil(tags),
         trimmed_tags <- String.trim(tags),
         tags_list <- String.split(trimmed_tags, ";"),
         {:filter_empty, [_ | _] = filtered_tags} <- {:filter_empty, Enum.filter(tags_list, fn tag -> tag != "" end)},
         trimmed_spaces_tags <- Enum.map(filtered_tags, fn tag -> String.trim(tag) end),
         {:validate, false} <- {:validate, Enum.any?(tags_list, fn tag -> String.length(tag) > @max_tag_length end)},
         {:uniqueness, true} <-
           {:uniqueness,
            Enum.count(Enum.uniq_by(trimmed_spaces_tags, &String.downcase(&1))) == Enum.count(trimmed_spaces_tags)},
         trimmed_tags_list <- Enum.take(trimmed_spaces_tags, @max_tags_per_request) do
      force_change(changeset, :tags, Enum.join(trimmed_tags_list, ";"))
    else
      {:uniqueness, false} ->
        add_error(changeset, :tags, "All tags should be unique")

      {:filter_empty, _} ->
        add_error(changeset, :tags, "All tags are empty strings")

      {:validate, _} ->
        add_error(changeset, :tags, "Tags should contain less than #{@max_tag_length} characters")

      _ ->
        add_error(changeset, :tags, "No tags")
    end
  end

  def public_tags_requests_by_identity_id_query(id) when not is_nil(id) do
    __MODULE__
    |> where(
      [request],
      request.identity_id == ^id and request.request_type != "delete" and not is_nil(request.request_id)
    )
    |> order_by([request], desc: request.id)
  end

  def public_tags_requests_by_identity_id_query(_), do: nil

  def public_tags_request_by_id_and_identity_id_query(id, identity_id)
      when not is_nil(id) and not is_nil(identity_id) do
    __MODULE__
    |> where([public_tags_request], public_tags_request.identity_id == ^identity_id and public_tags_request.id == ^id)
  end

  def public_tags_request_by_id_and_identity_id_query(_, _), do: nil

  def get_public_tags_request_by_id_and_identity_id(id, identity_id) when not is_nil(id) and not is_nil(identity_id) do
    id |> public_tags_request_by_id_and_identity_id_query(identity_id) |> Repo.account_repo().one()
  end

  def get_public_tags_request_by_id_and_identity_id(_, _), do: nil

  def get_public_tags_requests_by_identity_id(id) when not is_nil(id) do
    id
    |> public_tags_requests_by_identity_id_query()
    |> Repo.account_repo().all()
  end

  def get_public_tags_requests_by_identity_id(_), do: nil

  def delete_public_tags_request(identity_id, id) when not is_nil(id) and not is_nil(identity_id) do
    id
    |> public_tags_request_by_id_and_identity_id_query(identity_id)
    |> Repo.account_repo().delete_all()
  end

  def delete_public_tags_request(_, _), do: nil

  def update(%{id: id, identity_id: identity_id} = attrs) do
    with public_tags_request <- get_public_tags_request_by_id_and_identity_id(id, identity_id),
         false <- is_nil(public_tags_request),
         {:ok, changeset} <-
           public_tags_request |> changeset(Map.put(attrs, :request_type, "edit")) |> Repo.account_repo().update() do
      AirTable.submit({:ok, changeset})
    else
      true ->
        {:error, %{reason: :item_not_found}}

      other ->
        other
    end
  end

  def mark_as_deleted_public_tags_request(%{id: id, identity_id: identity_id, remove_reason: remove_reason}) do
    with public_tags_request <- get_public_tags_request_by_id_and_identity_id(id, identity_id),
         false <- is_nil(public_tags_request),
         {:ok, changeset} <-
           public_tags_request
           |> changeset_without_constraints(%{request_type: "delete", remove_reason: remove_reason})
           |> Repo.account_repo().update() do
      case AirTable.submit({:ok, changeset}) do
        {:error, changeset} ->
          changeset

        _ ->
          true
      end
    else
      {:error, changeset} ->
        changeset

      _ ->
        false
    end
  end

  def get_max_public_tags_request_count, do: @max_public_tags_request_per_account

  @doc """
  Merges public tags requests from multiple identities into a primary identity.

  This function updates the `identity_id` of all public tags requests belonging to the
  identities specified in `ids_to_merge` to the `primary_id`. It's designed to
  be used as part of an Ecto.Multi transaction.

  ## Parameters
  - `multi`: An Ecto.Multi struct to which this operation will be added.
  - `primary_id`: The ID of the primary identity that will own the merged keys.
  - `ids_to_merge`: A list of identity IDs whose public tags requests will be merged.

  ## Returns
  - An updated Ecto.Multi struct with the merge operation added.
  """
  @spec merge(Multi.t(), integer(), [integer()]) :: Multi.t()
  def merge(multi, primary_id, ids_to_merge) do
    Multi.run(multi, :merge_public_tags_requests, fn repo, _ ->
      {:ok,
       repo.update_all(
         from(key in __MODULE__, where: key.identity_id in ^ids_to_merge),
         set: [identity_id: primary_id]
       )}
    end)
  end
end
