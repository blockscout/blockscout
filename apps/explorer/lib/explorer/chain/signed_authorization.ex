defmodule Explorer.Chain.SignedAuthorization do
  @moduledoc "Models a transaction extension with authorization tuples from eip7702 set code transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Cache.ChainId, Data, Hash, Transaction}

  @optional_attrs ~w(authority status)a
  @required_attrs ~w(transaction_hash index chain_id address nonce r s v)a

  @typedoc """
  Descriptor of the signed authorization tuple from EIP-7702 set code transactions:
    * `transaction_hash` - the hash of the associated transaction.
    * `index` - the index of this authorization in the authorization list.
    * `chain_id` - the ID of the chain for which the authorization was created.
    * `address` - the address of the delegate contract.
    * `nonce` - the signature nonce.
    * `v` - the 'v' component of the signature.
    * `r` - the 'r' component of the signature.
    * `s` - the 's' component of the signature.
    * `authority` - the signer of the authorization.
    * `status` - the status of the authorization.
  """
  @type to_import :: %{
          transaction_hash: binary(),
          index: non_neg_integer(),
          chain_id: non_neg_integer(),
          address: binary(),
          nonce: non_neg_integer(),
          r: non_neg_integer(),
          s: non_neg_integer(),
          v: non_neg_integer(),
          authority: binary() | nil,
          status: :ok | :invalid_chain_id | :invalid_signature | :invalid_nonce | nil
        }

  @typedoc """
    * `transaction_hash` - the hash of the associated transaction.
    * `index` - the index of this authorization in the authorization list.
    * `chain_id` - the ID of the chain for which the authorization was created.
    * `address` - the address of the delegate contract.
    * `nonce` - the signature nonce.
    * `v` - the 'v' component of the signature.
    * `r` - the 'r' component of the signature.
    * `s` - the 's' component of the signature.
    * `authority` - the signer of the authorization.
    * `status` - the validity status of the authorization.
    * `inserted_at` - timestamp indicating when the signed authorization was created.
    * `updated_at` - timestamp indicating when the signed authorization was last updated.
    * `transaction` - an instance of `Explorer.Chain.Transaction` referenced by `transaction_hash`.
  """
  @primary_key false
  typed_schema "signed_authorizations" do
    field(:index, :integer, primary_key: true, null: false)
    field(:chain_id, :integer, null: false)
    field(:address, Hash.Address, null: false)
    field(:nonce, :decimal, null: false)
    field(:r, :decimal, null: false)
    field(:s, :decimal, null: false)
    field(:v, :integer, null: false)
    field(:authority, Hash.Address, null: true)
    field(:status, Ecto.Enum, values: [:ok, :invalid_chain_id, :invalid_signature, :invalid_nonce], null: true)

    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    timestamps()
  end

  @local_fields [:__meta__, :inserted_at, :updated_at]

  @doc """
    Returns a map representation of the signed authorization.
  """
  @spec to_map(__MODULE__.t()) :: map()
  def to_map(%__MODULE__{} = struct) do
    association_fields = struct.__struct__.__schema__(:associations)
    waste_fields = association_fields ++ @local_fields

    struct |> Map.from_struct() |> Map.drop(waste_fields)
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = struct, attrs \\ %{}) do
    struct
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_hash)
  end

  @doc """
  Converts a `SignedAuthorization.t()` into a map of import params that can be
  fed into `Chain.import/1`. It sets synthetic contract code for EIP-7702 proxies
  and updates the nonce.
  """
  @spec to_address_params(Ecto.Schema.t()) :: %{
          hash: Hash.Address.t(),
          contract_code: Data.t() | nil,
          nonce: non_neg_integer()
        }
  def to_address_params(%__MODULE__{} = struct) do
    code =
      if struct.address.bytes == <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>> do
        nil
      else
        %Data{bytes: <<239, 1, 0>> <> struct.address.bytes}
      end

    %{hash: struct.authority, contract_code: code, nonce: struct.nonce |> Decimal.to_integer()}
  end

  @doc """
  Does basic validation on a `SignedAuthorization.t()` according to EIP-7702, with
  the exception of verifying current authority nonce, which requires calling
  `eth_getTransactionCount` JSON-RPC method.

  Authority nonce validity is verified in async `Indexer.Fetcher.SignedAuthorizationStatus` fetcher.

  ## Returns
  - `:ok` if the signed authorization is valid and we should proceed with nonce validation.
  - `:invalid_chain_id` if the signed authorization is for another chain ID.
  - `:invalid_signature` if the signed authorization has an invalid signature.
  - `:invalid_nonce` if the signed authorization has an invalid nonce.
  - `nil` if the signed authorization status is unknown due to unknown chain ID.
  """
  @spec basic_validate(Ecto.Schema.t() | to_import()) ::
          :ok | :invalid_chain_id | :invalid_signature | :invalid_nonce | nil
  def basic_validate(%{} = struct) do
    chain_id = ChainId.get_id()

    cond do
      struct.chain_id != 0 and !is_nil(chain_id) and struct.chain_id != chain_id ->
        :invalid_chain_id

      struct.chain_id != 0 and is_nil(chain_id) ->
        nil

      struct.nonce |> Decimal.gte?(2 ** 64 - 1) ->
        :invalid_nonce

      is_nil(struct.authority) ->
        :invalid_signature

      true ->
        :ok
    end
  end
end
