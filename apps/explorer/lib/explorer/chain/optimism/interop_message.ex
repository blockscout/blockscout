defmodule Explorer.Chain.Optimism.InteropMessage do
  @moduledoc "Models interop message for Optimism."

  use Explorer.Schema

  alias Explorer.Chain.Hash
  #alias Explorer.Repo

  @required_attrs ~w(nonce init_chain_id relay_chain_id)a
  @optional_attrs ~w(sender target init_transaction_hash block_number timestamp relay_transaction_hash payload failed)a

  @typedoc """
    * `sender` - An address of the sender on the source chain. Can be a smart contract. Can be `nil` (when SentMessage event is not indexed yet).
    * `target` - A target address on the target chain. Can be a smart contract. Can be `nil` (when SentMessage event is not indexed yet).
    * `nonce` - Nonce associated with the messsage sent. Unique within the source chain.
    * `init_chain_id` - Chain ID of the source chain.
    * `init_transaction_hash` - Transaction hash (on the source chain) associated with the messsage sent. Can be `nil` (when SentMessage event is not indexed yet).
    * `block_number` - Block number of the `init_transaction_hash` for outgoing message. Block number of the `relay_transaction_hash` for incoming message.
    * `timestamp` - Timestamp of the `init_transaction_hash` transaction. Can be `nil` (when SentMessage event is not indexed yet).
    * `relay_chain_id` - Chain ID of the target chain.
    * `relay_transaction_hash` - Transaction hash (on the target chain) associated with the message relay transaction. Can be `nil` (when relay transaction is not indexed yet).
    * `payload` - Message payload to call target with. Can be `nil` (when SentMessage event is not indexed yet).
    * `failed` - Fail status of the relay transaction. Can be `nil` (when relay transaction is not indexed yet).
  """
  @primary_key false
  typed_schema "op_interop_messages" do
    field(:sender, Hash.Address)
    field(:target, Hash.Address)
    field(:nonce, :integer, primary_key: true)
    field(:init_chain_id, :integer, primary_key: true)
    field(:init_transaction_hash, Hash.Full)
    field(:block_number, :integer)
    field(:timestamp, :utc_datetime_usec)
    field(:relay_chain_id, :integer)
    field(:relay_transaction_hash, Hash.Full)
    field(:payload, :binary)
    field(:failed, :boolean)

    timestamps()
  end

  @doc """
    Validates that the attributes are valid.
  """
  def changeset(%__MODULE__{} = message, attrs \\ %{}) do
    message
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
  end

  # @doc """
  #   Reads the last row from the `op_eip1559_config_updates` table.
  #
  #   ## Returns
  #   - `{l2_block_number, l2_block_hash}` tuple for the last row.
  #   - `{0, nil}` if there are no rows in the table.
  # """
  # @spec get_last_item() :: {non_neg_integer(), binary() | nil}
  # def get_last_item do
  #   query =
  #     from(u in __MODULE__, select: {u.l2_block_number, u.l2_block_hash}, order_by: [desc: u.l2_block_number], limit: 1)
  #
  #   query
  #   |> Repo.one()
  #   |> Kernel.||({0, nil})
  # end
end
