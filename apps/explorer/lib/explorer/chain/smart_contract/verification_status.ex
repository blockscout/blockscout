defmodule Explorer.Chain.SmartContract.VerificationStatus do
    @moduledoc """
    Represents single verification try
    """
  
    use Explorer.Schema
  
    import Ecto.Changeset
  
    alias Explorer.Chain.Hash
    alias Explorer.{Chain, Repo}
    alias Ecto.Changeset
    
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
      field(:address_hash, :string)
  
      timestamps()
    end
  
    @required_fields ~w(uid status address_hash)a

    def changeset(%__MODULE__{} = struct, params \\ %{}) do
      struct
      |> cast(params, @required_fields)
      |> validate_required(@required_fields)
      |> encode_status()  
    end

    def encode_status(%Changeset{valid?: false} = changeset), do: changeset

    def encode_status(%Changeset{valid?: true} = changeset) do
        case get_change(changeset, :status) do
            change when change in [0, 1, 2, nil] ->
                changeset
            :pending ->
                put_change(changeset, :status, 0)
            :pass ->
                put_change(changeset, :status, 1)
            :fail ->
                put_change(changeset, :status, 2)
            _ ->
                add_error(changeset, :status, "Invalid status")
        end
    end

    def decode_status(number) when number in [0, 1, 2] do
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
        %__MODULE__{uid: uid, status: status, address_hash: address_hash}
        |> changeset()
        |> Repo.insert()
    end

    def update_status(uid, status) do
        %__MODULE__{uid: uid, status: status}
        |> changeset()
        |> Repo.update()
    end

    def fetch_status(uid) do
        __MODULE__
        |> Repo.get_by(uid: uid)
        |> (&(if is_nil(&1), do: 3, else: Map.get(&1, :status))).()
        |> decode_status()
    end

    def generate_uid(address_hash) do
        case Chain.string_to_address_hash(address_hash) do
            :error ->
                nil
            address_hash ->
                address_encoded = Base.encode16(address_hash, case: :lower)
                timestamp = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string(16) |> String.downcase()
                address_encoded <> timestamp
        end 
    end
end