defmodule Explorer.Chain.UserOperation do
  @moduledoc """
  The representation of a user operation for account abstraction (EIP-4337).
  """

  require Logger

  import Ecto.Query,
    only: [
      where: 2
    ]

  use Explorer.Schema
  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Explorer.Utility.Microservice

  @type api? :: {:api?, true | false}

  @typedoc """
  * `hash` - the hash of User operation.
  * `block_number` - the block number, where user operation happened.
  * `block_hash` - the block hash, where user operation happened.
  """
  @primary_key false
  typed_schema "user_operations" do
    field(:hash, Hash.Full, primary_key: true, null: false)
    field(:block_number, :integer, null: false)
    field(:block_hash, Hash.Full, null: false)

    timestamps()
  end

  def changeset(%__MODULE__{} = user_operation, attrs) do
    user_operation
    |> cast(attrs, [
      :hash,
      :block_number,
      :block_hash
    ])
    |> validate_required([:hash, :block_number, :block_hash])
  end

  @doc """
  Converts `t:Explorer.Chain.UserOperation.t/0` `hash` to the `t:Explorer.Chain.UserOperation.t/0` with that `hash`.
  """
  @spec hash_to_user_operation(Hash.Full.t(), [api?]) ::
          {:ok, __MODULE__.t()} | {:error, :not_found}
  def hash_to_user_operation(%Hash{byte_count: unquote(Hash.Full.byte_count())} = hash, options \\ [])
      when is_list(options) do
    __MODULE__
    |> where(hash: ^hash)
    |> Chain.select_repo(options).one()
    |> case do
      nil ->
        {:error, :not_found}

      user_operation ->
        {:ok, user_operation}
    end
  end

  def enabled? do
    Microservice.check_enabled(Explorer.MicroserviceInterfaces.AccountAbstraction) == :ok
  end
end
