defmodule Explorer.Faucet.FaucetRequest do
  @moduledoc """
  Faucet requests history.

  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Faucet.FaucetRequest

  @typedoc """
  * `receiver_hash` - Hash of faucet coins receiver
  """
  @type t :: %FaucetRequest{
          receiver_hash: Hash.Address.t(),
          phone_hash: Hash.Full.t(),
          session_key_hash: Hash.Full.t(),
          verification_code_hash: Hash.Full.t(),
          verification_code_validation_attempts: non_neg_integer(),
          coins_sent: boolean()
        }

  @primary_key false
  schema "faucet_requests" do
    belongs_to(:address, Address, primary_key: true, foreign_key: :receiver_hash, references: :hash, type: Hash.Address)
    field(:phone_hash, Hash.Full, primary_key: true)
    field(:session_key_hash, Hash.Full, primary_key: true)
    field(:verification_code_hash, Hash.Full)
    field(:verification_code_validation_attempts, :integer)
    field(:coins_sent, :boolean)

    timestamps()
  end

  @optional_attrs ~w(phone_hash session_key_hash verification_code_hash verification_code_validation_attempts coins_sent)a
  @required_attrs ~w(receiver_hash)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @doc false
  def changeset(%FaucetRequest{} = faucet_request, params \\ %{}) do
    faucet_request
    |> cast(params, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:receiver_hash)
  end
end
