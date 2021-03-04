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
          receiver_hash: Hash.Address.t()
        }

  @primary_key false
  schema "faucet_requests" do
    belongs_to(:address, Address, foreign_key: :receiver_hash, references: :hash, type: Hash.Address)

    timestamps()
  end

  @required_attrs ~w(receiver_hash)a

  @doc false
  def changeset(%FaucetRequest{} = faucet_request, params \\ %{}) do
    faucet_request
    |> cast(params, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:receiver_hash)
  end
end
