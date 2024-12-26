defmodule Explorer.Account.CustomABI do
  @moduledoc """
    Module is responsible for schema for API keys, keys is used to track number of requests to the API endpoints
  """
  use Explorer.Schema

  alias ABI.FunctionSelector
  alias Ecto.{Changeset, Multi}
  alias Explorer.Account.Identity
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Hash

  import Explorer.Chain, only: [hash_to_lower_case_string: 1]
  import Ecto.Changeset

  @max_abis_per_account 15

  @user_not_found "User not found"

  typed_schema "account_custom_abis" do
    field(:abi, {:array, :map}, null: false)
    field(:given_abi, :string, virtual: true)
    field(:abi_validating_error, :string, virtual: true)
    field(:address_hash_hash, Cloak.Ecto.SHA256) :: binary() | nil
    field(:address_hash, Explorer.Encrypted.AddressHash, null: false)
    field(:name, Explorer.Encrypted.Binary, null: false)
    field(:user_created, :boolean, null: false, default: true)

    belongs_to(:identity, Identity, null: false)

    timestamps()
  end

  @attrs ~w(name abi identity_id address_hash)a

  def changeset(%__MODULE__{} = custom_abi \\ %__MODULE__{}, attrs \\ %{}) do
    custom_abi
    |> cast(check_is_abi_valid?(attrs), @attrs ++ [:id, :given_abi, :abi_validating_error])
    |> validate_required(@attrs, message: "Required")
    |> validate_custom_abi()
    |> check_smart_contract_address()
    |> foreign_key_constraint(:identity_id, message: @user_not_found)
    |> put_hashed_fields()
    |> unique_constraint([:identity_id, :address_hash_hash],
      message: "Custom ABI for this address has already been added before"
    )
    |> custom_abi_count_constraint()
  end

  def changeset_without_constraints(%__MODULE__{} = custom_abi \\ %__MODULE__{}, attrs \\ %{}) do
    custom_abi
    |> cast(attrs, [:id | @attrs])
    |> validate_required(@attrs, message: "Required")
  end

  defp put_hashed_fields(changeset) do
    # Using force_change instead of put_change due to https://github.com/danielberkompas/cloak_ecto/issues/53
    changeset
    |> force_change(:address_hash_hash, hash_to_lower_case_string(get_field(changeset, :address_hash)))
  end

  defp check_smart_contract_address(%Changeset{changes: %{address_hash: address_hash}} = custom_abi) do
    check_smart_contract_address_inner(custom_abi, address_hash)
  end

  defp check_smart_contract_address(%Changeset{data: %{address_hash: address_hash}} = custom_abi) do
    check_smart_contract_address_inner(custom_abi, address_hash)
  end

  defp check_smart_contract_address(custom_abi), do: custom_abi

  defp check_smart_contract_address_inner(changeset, address_hash) do
    if Chain.address_hash_is_smart_contract?(address_hash) do
      changeset
    else
      add_error(changeset, :address_hash, "Address is not a smart contract")
    end
  end

  defp validate_custom_abi(%Changeset{changes: %{given_abi: given_abi, abi_validating_error: error}} = custom_abi) do
    custom_abi
    |> add_error(:abi, error)
    |> force_change(:abi, given_abi)
  end

  defp validate_custom_abi(custom_abi), do: custom_abi

  defp check_is_abi_valid?(%{abi: abi} = custom_abi) when is_binary(abi) do
    with {:ok, decoded} <- Jason.decode(abi),
         true <- is_list(decoded) do
      custom_abi
      |> Map.put(:abi, decoded)
      |> check_is_abi_valid?(abi)
    else
      _ ->
        custom_abi
        |> Map.put(:abi, "")
        |> Map.put(:given_abi, abi)
        |> Map.put(:abi_validating_error, "Invalid format")
    end
  end

  defp check_is_abi_valid?(custom_abi, given_abi \\ nil)

  defp check_is_abi_valid?(%{abi: abi} = custom_abi, given_abi) when is_list(abi) do
    with true <- length(abi) > 0,
         filtered_abi <- filter_abi(abi),
         false <- Enum.empty?(filtered_abi) do
      Map.put(custom_abi, :abi, filtered_abi)
    else
      _ ->
        custom_abi
        |> Map.put(:abi, "")
        |> (&if(is_nil(given_abi),
              do: Map.put(&1, :given_abi, Jason.encode!(abi)),
              else: Map.put(&1, :given_abi, given_abi)
            )).()
        |> Map.put(:abi_validating_error, "ABI must contain functions")
    end
  end

  defp check_is_abi_valid?(custom_abi, _), do: custom_abi

  defp filter_abi(abi_list) when is_list(abi_list) do
    Enum.filter(abi_list, &is_abi_function(&1))
  end

  defp is_abi_function(abi_item) when is_map(abi_item) do
    case ABI.parse_specification([abi_item], include_events?: false) do
      [%FunctionSelector{type: :constructor}] ->
        false

      [_] ->
        true

      _ ->
        false
    end
  end

  def custom_abi_count_constraint(%Changeset{changes: %{identity_id: identity_id}} = custom_abi) do
    if identity_id
       |> custom_abis_by_identity_id_query()
       |> limit(@max_abis_per_account)
       |> Repo.account_repo().aggregate(:count, :id) >= @max_abis_per_account do
      add_error(custom_abi, :name, "Max #{@max_abis_per_account} ABIs per account")
    else
      custom_abi
    end
  end

  def custom_abi_count_constraint(%Changeset{} = custom_abi), do: custom_abi

  @doc """
  Creates a new custom ABI entry for a smart contract address.

  The function performs several validations including checking the ABI format,
  verifying the smart contract address, and ensuring the user hasn't exceeded their
  ABI limit. The operation is executed within a database transaction that includes
  identity verification.

  ## Parameters
  - `attrs`: A map containing:
    - `identity_id`: The ID of the user creating the ABI
    - `abi`: The ABI specification as a JSON string or list of maps
    - `name`: The name for this custom ABI entry
    - `address_hash`: The smart contract address this ABI corresponds to

  ## Returns
  - `{:ok, custom_abi}` if the creation is successful
  - `{:error, changeset}` if:
    - The identity doesn't exist
    - The ABI format is invalid
    - The address is not a smart contract
    - The user has reached their ABI limit
    - The ABI already exists for this address
    - Required fields are missing
  """
  @spec create(map()) :: {:ok, t()} | {:error, Changeset.t()}
  def create(%{identity_id: identity_id} = attrs) do
    Multi.new()
    |> Identity.acquire_with_lock(identity_id)
    |> Multi.insert(:custom_abi, fn _ ->
      %__MODULE__{}
      |> changeset(attrs)
    end)
    |> Repo.account_repo().transaction()
    |> case do
      {:ok, %{custom_abi: custom_abi}} ->
        {:ok, custom_abi}

      {:error, :acquire_identity, :not_found, _changes} ->
        {:error,
         %__MODULE__{}
         |> changeset(attrs)
         |> add_error(:identity_id, @user_not_found,
           constraint: :foreign,
           constraint_name: "account_custom_abis_identity_id_fkey"
         )}

      {:error, _failed_operation, error, _changes} ->
        {:error, error}
    end
  end

  def create(attrs) do
    {:error,
     %__MODULE__{}
     |> changeset(attrs)}
  end

  def custom_abis_by_identity_id_query(id) when not is_nil(id) do
    __MODULE__
    |> where([abi], abi.identity_id == ^id)
    |> order_by([abi], desc: abi.id)
  end

  def custom_abis_by_identity_id_query(_), do: nil

  def custom_abi_by_id_and_identity_id_query(id, identity_id)
      when not is_nil(id) and not is_nil(identity_id) do
    __MODULE__
    |> where([custom_abi], custom_abi.identity_id == ^identity_id and custom_abi.id == ^id)
  end

  def custom_abi_by_id_and_identity_id_query(_, _), do: nil

  def custom_abi_by_identity_id_and_address_hash_query(address_hash, identity_id)
      when not is_nil(identity_id) and not is_nil(address_hash) do
    __MODULE__
    |> where([custom_abi], custom_abi.identity_id == ^identity_id and custom_abi.address_hash_hash == ^address_hash)
  end

  def custom_abi_by_identity_id_and_address_hash_query(_, _), do: nil

  @doc """
  Retrieves a custom ABI for a given address hash and identity ID.

  This function searches for a custom ABI associated with the provided address
  hash and identity ID. It returns the first matching ABI if found, or nil if no
  matching ABI exists.

  ## Parameters
  - `address_hash`: The address hash to search for. Can be a `Hash.Address.t()`,
    `String.t()`, or `nil`.
  - `identity_id`: The identity ID associated with the custom ABI. Can be an
    `integer()` or `nil`.

  ## Returns
  - A `Explorer.Account.CustomABI` struct if a matching ABI is found.
  - `nil` if no matching ABI is found or if either input is nil.
  """
  @spec get_custom_abi_by_identity_id_and_address_hash(Hash.Address.t() | String.t() | nil, integer() | nil) ::
          __MODULE__.t() | nil
  def get_custom_abi_by_identity_id_and_address_hash(address_hash, identity_id)
      when not is_nil(identity_id) and not is_nil(address_hash) do
    abis =
      address_hash
      |> hash_to_lower_case_string()
      |> custom_abi_by_identity_id_and_address_hash_query(identity_id)
      |> Repo.account_repo().all()

    case abis do
      [abi | _] -> abi
      _ -> nil
    end
  end

  def get_custom_abi_by_identity_id_and_address_hash(_, _), do: nil

  def get_custom_abi_by_id_and_identity_id(id, identity_id) when not is_nil(id) and not is_nil(identity_id) do
    id
    |> custom_abi_by_id_and_identity_id_query(identity_id)
    |> Repo.account_repo().one()
  end

  def get_custom_abi_by_id_and_identity_id(_, _), do: nil

  def get_custom_abis_by_identity_id(id) when not is_nil(id) do
    id
    |> custom_abis_by_identity_id_query()
    |> Repo.account_repo().all()
  end

  def get_custom_abis_by_identity_id(_), do: nil

  def delete(id, identity_id) when not is_nil(id) and not is_nil(identity_id) do
    id
    |> custom_abi_by_id_and_identity_id_query(identity_id)
    |> Repo.account_repo().delete_all()
  end

  def delete(_, _), do: nil

  def update(%{id: id, identity_id: identity_id} = attrs) do
    with custom_abi <- get_custom_abi_by_id_and_identity_id(id, identity_id),
         false <- is_nil(custom_abi) do
      custom_abi
      |> changeset(attrs)
      |> Repo.account_repo().update()
    else
      true ->
        {:error, %{reason: :item_not_found}}
    end
  end

  def get_max_custom_abis_count, do: @max_abis_per_account

  @doc """
  Merges custom ABIs from multiple identities into a primary identity.

  This function updates all custom ABIs associated with the identities specified
  in `ids_to_merge` to be associated with the `primary_id`. It also marks these
  ABIs as not user-created in order to satisfy database constraint.

  ## Parameters
  - `multi`: An `Ecto.Multi` struct to which the merge operation will be added.
  - `primary_id`: An integer representing the ID of the primary identity to
    which the custom ABIs will be merged.
  - `ids_to_merge`: A list of integer IDs representing the identities whose
    custom ABIs will be merged into the primary identity.

  ## Returns
  - An updated `Ecto.Multi` struct with the merge operation added.
  """
  @spec merge(Multi.t(), integer(), [integer()]) :: Multi.t()
  def merge(multi, primary_id, ids_to_merge) do
    Multi.run(multi, :merge_custom_abis, fn repo, _ ->
      {:ok,
       repo.update_all(
         from(key in __MODULE__, where: key.identity_id in ^ids_to_merge),
         set: [identity_id: primary_id, user_created: false]
       )}
    end)
  end
end
