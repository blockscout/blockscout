defmodule Explorer.Chain.SmartContract.Proxy.VerificationStatus do
  @moduledoc """
    Represents single proxy verification submission
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain.Hash
  alias Explorer.{Chain, Repo}

  @typedoc """
  * `address_hash` - address of the contract which was tried to verify
  * `status` - submission status: :pending | :pass | :fail
  * `uid` - unique verification identifier
  """

  @type t :: %__MODULE__{
          uid: String.t(),
          address_hash: Hash.Address.t(),
          status: non_neg_integer()
        }

  @primary_key false
  schema "proxy_verification_status" do
    field(:uid, :string, primary_key: true)
    field(:status, Ecto.Enum, values: [pending: 0, pass: 1, fail: 2])
    field(:address_hash, Hash.Address)

    timestamps()
  end

  @required_fields ~w(uid status address_hash)a

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end

  def insert_status(uid, status, address_hash) do
    {:ok, hash} = if is_binary(address_hash), do: Chain.string_to_address_hash(address_hash), else: {:ok, address_hash}

    %__MODULE__{}
    |> changeset(%{uid: uid, status: status, address_hash: hash})
    |> Repo.insert()
  end

  def update_status(uid, status) do
    __MODULE__
    |> Repo.get_by(uid: uid)
    |> changeset(%{status: status})
    |> Repo.update()
  end

  def fetch_status(uid) do
    case validate_uid(uid) do
      {:ok, valid_uid} ->
        __MODULE__
        |> Repo.get_by(uid: valid_uid)

      _ ->
        :unknown_uid
    end
  end

  def generate_uid(%Hash{byte_count: 20, bytes: address_hash}) do
    address_encoded = Base.encode16(address_hash, case: :lower)
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string(16) |> String.downcase()
    address_encoded <> timestamp
  end

  def validate_uid(<<_address::binary-size(40), timestamp_hex::binary>> = uid) do
    case Integer.parse(timestamp_hex, 16) do
      {timestamp, ""} ->
        if DateTime.utc_now() |> DateTime.to_unix() > timestamp do
          {:ok, uid}
        else
          :error
        end

      _ ->
        :error
    end
  end

  def validate_uid(_), do: :error

  def set_proxy_verification_result({empty_or_nil, _}, uid) when empty_or_nil in [:empty, nil],
    do: update_status(uid, :fail)

  def set_proxy_verification_result({_, _}, uid), do: update_status(uid, :pass)
end
