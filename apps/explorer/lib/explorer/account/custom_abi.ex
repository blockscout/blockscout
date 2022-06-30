defmodule Explorer.Account.CustomABI do
  @moduledoc """
    Module is responsible for schema for API keys, keys is used to track number of requests to the API endpoints
  """
  use Explorer.Schema

  alias ABI.FunctionSelector
  alias Ecto.Changeset
  alias Explorer.Account.Identity
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash}

  import Ecto.Changeset

  @max_abis_per_account 15

  schema "account_custom_abis" do
    field(:name, :string)
    field(:abi, {:array, :map})
    field(:given_abi, :string, virtual: true)
    field(:abi_validating_error, :string, virtual: true)
    belongs_to(:identity, Identity)
    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address)

    timestamps()
  end

  @attrs ~w(name abi identity_id address_hash)a

  def changeset(%__MODULE__{} = custom_abi \\ %__MODULE__{}, attrs \\ %{}) do
    custom_abi
    |> cast(check_is_abi_valid?(attrs), @attrs ++ [:id, :given_abi, :abi_validating_error])
    |> validate_required(@attrs, message: "Required")
    |> validate_custom_abi()
    |> check_smart_contract_address()
    |> foreign_key_constraint(:identity_id, message: "User not found")
    |> foreign_key_constraint(:address_hash, message: "Address not found")
    |> unique_constraint([:identity_id, :address_hash],
      message: "Custom ABI for this address has already been added before"
    )
    |> custom_abi_count_constraint()
  end

  def changeset_without_constraints(%__MODULE__{} = custom_abi \\ %__MODULE__{}, attrs \\ %{}) do
    custom_abi
    |> cast(attrs, [:id | @attrs])
    |> validate_required(@attrs, message: "Required")
  end

  defp check_smart_contract_address(%Changeset{changes: %{address_hash: address_hash}} = custom_abi) do
    if Chain.is_address_hash_is_smart_contract?(address_hash) do
      custom_abi
    else
      add_error(custom_abi, :address_hash, "Address is not a smart contract")
    end
  end

  defp check_smart_contract_address(%Changeset{data: %{address_hash: address_hash}} = custom_abi) do
    if Chain.is_address_hash_is_smart_contract?(address_hash) do
      custom_abi
    else
      add_error(custom_abi, :address_hash, "Address is not a smart contract")
    end
  end

  defp check_smart_contract_address(custom_abi), do: custom_abi

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
         true <- Enum.count(filtered_abi) > 0 do
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
       |> Repo.aggregate(:count, :id) >= @max_abis_per_account do
      add_error(custom_abi, :name, "Max #{@max_abis_per_account} ABIs per account")
    else
      custom_abi
    end
  end

  def custom_abi_count_constraint(%Changeset{} = custom_abi), do: custom_abi

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def custom_abis_by_identity_id_query(id) when not is_nil(id) do
    __MODULE__
    |> where([abi], abi.identity_id == ^id)
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
    |> where([custom_abi], custom_abi.identity_id == ^identity_id and custom_abi.address_hash == ^address_hash)
  end

  def custom_abi_by_identity_id_and_address_hash_query(_, _), do: nil

  def get_custom_abi_by_identity_id_and_address_hash(address_hash, identity_id)
      when not is_nil(identity_id) and not is_nil(address_hash) do
    address_hash
    |> custom_abi_by_identity_id_and_address_hash_query(identity_id)
    |> Repo.one()
  end

  def get_custom_abi_by_identity_id_and_address_hash(_, _), do: nil

  def get_custom_abi_by_id_and_identity_id(id, identity_id) when not is_nil(id) and not is_nil(identity_id) do
    id
    |> custom_abi_by_id_and_identity_id_query(identity_id)
    |> Repo.one()
  end

  def get_custom_abi_by_id_and_identity_id(_, _), do: nil

  def get_custom_abis_by_identity_id(id) when not is_nil(id) do
    id
    |> custom_abis_by_identity_id_query()
    |> Repo.all()
  end

  def get_custom_abis_by_identity_id(_), do: nil

  def delete(id, identity_id) when not is_nil(id) and not is_nil(identity_id) do
    id
    |> custom_abi_by_id_and_identity_id_query(identity_id)
    |> Repo.delete_all()
  end

  def delete(_, _), do: nil

  def update(%{id: id, identity_id: identity_id} = attrs) do
    with custom_abi <- get_custom_abi_by_id_and_identity_id(id, identity_id),
         false <- is_nil(custom_abi) do
      custom_abi
      |> changeset(attrs)
      |> Repo.update()
    else
      true ->
        {:error, %{reason: :item_not_found}}
    end
  end
end
