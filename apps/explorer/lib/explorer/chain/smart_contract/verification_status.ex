defmodule Explorer.Chain.SmartContract.VerificationStatus do
  @moduledoc """
  Represents single verification try
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain.Hash
  alias Explorer.{Chain, Repo}

  @typedoc """
  * `address_hash` - address of the contract which was tried to verify
  * `status` - name for the address
  * `uid` - flag for if the name is the primary name for the address
  """

  @type status :: :pending | :pass | :fail | 0 | 1 | 2

  @type t :: %__MODULE__{
          uid: String.t(),
          address_hash: Hash.Address.t(),
          status: non_neg_integer()
        }

  @primary_key false
  schema "contract_verification_status" do
    field(:uid, :string, primary_key: true)
    field(:status, :integer)
    field(:address_hash, Hash.Address)

    timestamps()
  end

  @required_fields ~w(uid status address_hash)a

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    casted_params = encode_status(params)
		to_return =
			struct
			|> cast(casted_params, @required_fields)
			|> validate_required(@required_fields)
		to_return
  end

  def encode_status(%{status: status} = changeset) do
    case status do
      :pending ->
        Map.put(changeset, :status, 0)

      :pass ->
        Map.put(changeset, :status, 1)

      :fail ->
        Map.put(changeset, :status, 2)

      _ ->
        changeset
    end
  end

  def decode_status(number) when number in [0, 1, 2, 3] do
    case number do
      0 ->
        :pending

      1 ->
        :pass

      2 ->
        :fail

      3 ->
        :unknown_uid
    end
  end

  def insert_status(uid, status, address_hash) do
    {:ok, hash} = if is_binary(address_hash), do: Chain.string_to_address_hash(address_hash), else: address_hash

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
    __MODULE__
    |> Repo.get_by(uid: uid)
    |> (&if(is_nil(&1), do: 3, else: Map.get(&1, :status))).()
    |> decode_status()
  end

  def generate_uid(address_hash) do
    case Chain.string_to_address_hash(address_hash) do
      :error ->
        nil

      {:ok, %Explorer.Chain.Hash{byte_count: 20, bytes: address_hash}} ->
        address_encoded = Base.encode16(address_hash, case: :lower)
        timestamp = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string(16) |> String.downcase()
        address_encoded <> timestamp
    end
  end
end
