defmodule Explorer.Chain.SmartContract.Proxy.VerificationStatus do
  @moduledoc """
    Represents single proxy verification submission
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain.Hash
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.{Chain, Repo}

  @typep status :: integer() | atom()

  @typedoc """
  * `contract_address_hash` - address of the contract which was tried to verify
  * `status` - submission status: :pending | :pass | :fail
  * `uid` - unique verification identifier
  """
  @primary_key false
  typed_schema "proxy_smart_contract_verification_statuses" do
    field(:uid, :string, primary_key: true, null: false)
    field(:status, Ecto.Enum, values: [pending: 0, pass: 1, fail: 2], null: false)
    field(:contract_address_hash, Hash.Address, null: false)

    timestamps()
  end

  @required_fields ~w(uid status contract_address_hash)a

  @doc """
    Creates a changeset based on the `struct` and `params`.
  """
  @spec changeset(Explorer.Chain.SmartContract.Proxy.VerificationStatus.t()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end

  @doc """
    Inserts verification status
  """
  @spec insert_status(String.t(), status(), Hash.Address.t() | String.t()) :: any()
  def insert_status(uid, status, address_hash) do
    {:ok, hash} = if is_binary(address_hash), do: Chain.string_to_address_hash(address_hash), else: {:ok, address_hash}

    %__MODULE__{}
    |> changeset(%{uid: uid, status: status, contract_address_hash: hash})
    |> Repo.insert()
  end

  @doc """
    Updates verification status
  """
  @spec update_status(String.t(), status()) :: __MODULE__.t()
  def update_status(uid, status) do
    __MODULE__
    |> Repo.get_by(uid: uid)
    |> changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
    Fetches verification status
  """
  @spec fetch_status(binary()) :: __MODULE__.t() | nil
  def fetch_status(uid) do
    case validate_uid(uid) do
      {:ok, valid_uid} ->
        __MODULE__
        |> Repo.get_by(uid: valid_uid)

      _ ->
        nil
    end
  end

  @doc """
    Generates uid based on address hash and timestamp
  """
  @spec generate_uid(Explorer.Chain.Hash.t()) :: String.t()
  def generate_uid(%Hash{byte_count: 20, bytes: address_hash}) do
    address_encoded = Base.encode16(address_hash, case: :lower)
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string(16) |> String.downcase()
    address_encoded <> timestamp
  end

  @doc """
    Validates uid
  """
  @spec validate_uid(String.t()) :: :error | {:ok, <<_::64, _::_*8>>}
  def validate_uid(<<_address::binary-size(40), timestamp_hex::binary>> = uid) do
    case Integer.parse(timestamp_hex, 16) do
      {timestamp, ""} ->
        if DateTime.utc_now() |> DateTime.to_unix() >= timestamp do
          {:ok, uid}
        else
          :error
        end

      _ ->
        :error
    end
  end

  def validate_uid(_), do: :error

  @doc """
    Sets proxy verification result
  """
  @spec set_proxy_verification_result(Implementation.t() | :empty | :error, String.t()) :: __MODULE__.t()
  def set_proxy_verification_result(%Implementation{}, uid), do: update_status(uid, :pass)

  def set_proxy_verification_result(_empty_or_error, uid), do: update_status(uid, :fail)
end
