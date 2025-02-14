defmodule Explorer.Chain.Optimism.InteropMessage do
  @moduledoc "Models interop message for Optimism."

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Repo

  @required_attrs ~w(nonce init_chain_id relay_chain_id)a
  @optional_attrs ~w(sender target init_transaction_hash block_number timestamp relay_transaction_hash payload failed)a

  @typedoc """
    * `sender` - An address of the sender on the source chain. Can be a smart contract. Can be `nil` (when SentMessage event is not indexed yet).
    * `target` - A target address on the target chain. Can be a smart contract. Can be `nil` (when SentMessage event is not indexed yet).
    * `nonce` - Nonce associated with the message sent. Unique within the source chain.
    * `init_chain_id` - Chain ID of the source chain.
    * `init_transaction_hash` - Transaction hash (on the source chain) associated with the message sent. Can be `nil` (when SentMessage event is not indexed yet).
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

  @doc """
    Removes rows from the `op_interop_messages` table which have a block number
    greater than the latest block number. They could be created due to reorg.

    ## Parameters
    - `latest_block_number`: The latest block number.

    ## Returns
    - A number of removed rows.
  """
  @spec remove_invalid_messages(integer()) :: non_neg_integer()
  def remove_invalid_messages(latest_block_number) do
    {deleted_count, _} =
      Repo.delete_all(from(m in __MODULE__, where: m.block_number > ^latest_block_number), timeout: :infinity)

    deleted_count
  end

  @doc """
    Reads the last row from the `op_interop_messages` table.

    ## Parameters
    - `current_chain_id`: The current chain ID.
    - `only_failed`: True if only failed relay transactions are taken into account.

    ## Returns
    - `{block_number, transaction_hash}` tuple for the last row.
    - `{0, nil}` if there are no rows in the table.
  """
  @spec get_last_item(non_neg_integer(), boolean()) :: {non_neg_integer(), binary() | nil}
  def get_last_item(current_chain_id, only_failed) do
    base_query =
      from(m in __MODULE__,
        select: {m.block_number, m.init_chain_id, m.init_transaction_hash, m.relay_chain_id, m.relay_transaction_hash},
        where: not is_nil(m.block_number),
        order_by: [desc: m.block_number],
        limit: 1
      )

    query =
      if only_failed do
        where(base_query, [m], m.failed == true)
      else
        base_query
      end

    message =
      query
      |> Repo.one()

    if is_nil(message) do
      {0, nil}
    else
      {block_number, init_chain_id, init_transaction_hash, relay_chain_id, relay_transaction_hash} = message

      cond do
        current_chain_id == init_chain_id ->
          {block_number, init_transaction_hash}

        current_chain_id == relay_chain_id ->
          {block_number, relay_transaction_hash}

        true ->
          {0, nil}
      end
    end
  end

  @doc """
    Returns a list of incomplete messages from the `op_interop_messages` table.
    An incomplete message is the message for which an init transaction or relay transaction is unknown.

    ## Parameters
    - `current_chain_id`: The current chain ID to make correct query to the database.

    ## Returns
    - A list of the incomplete messages. Returns an empty list if they are not found.
  """
  @spec get_incomplete_messages(non_neg_integer()) :: list()
  def get_incomplete_messages(current_chain_id) do
    Repo.all(from(m in __MODULE__,
      where: is_nil(m.relay_transaction_hash) and m.init_chain_id == ^current_chain_id or is_nil(m.init_transaction_hash) and m.relay_chain_id == ^current_chain_id
    ))
  end
end
