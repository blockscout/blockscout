defmodule Explorer.Chain.Signet.Order do
  @moduledoc """
    Models a Signet Order event from the RollupOrders contract.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Signet.Orders

    Migrations:
    - Explorer.Repo.Signet.Migrations.CreateSignetTables
  """

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Wei}

  @insert_result_key :insert_signet_orders

  @optional_attrs ~w(sweep_recipient sweep_token sweep_amount)a

  @required_attrs ~w(outputs_witness_hash deadline block_number transaction_hash log_index inputs_json outputs_json)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  Descriptor of a Signet Order event:
    * `outputs_witness_hash` - keccak256 hash of outputs for cross-chain correlation with fills
    * `deadline` - The deadline timestamp for the order
    * `block_number` - The block number where the order was created
    * `transaction_hash` - The hash of the transaction containing the order
    * `log_index` - The index of the log within the transaction
    * `inputs_json` - JSON-encoded array of input tokens and amounts
    * `outputs_json` - JSON-encoded array of output tokens, amounts, and recipients
    * `sweep_recipient` - Recipient address from Sweep event (if any)
    * `sweep_token` - Token address from Sweep event (if any)
    * `sweep_amount` - Amount from Sweep event (if any)
  """
  @type to_import :: %{
          outputs_witness_hash: binary(),
          deadline: non_neg_integer(),
          block_number: non_neg_integer(),
          transaction_hash: binary(),
          log_index: non_neg_integer(),
          inputs_json: String.t(),
          outputs_json: String.t(),
          sweep_recipient: binary() | nil,
          sweep_token: binary() | nil,
          sweep_amount: Decimal.t() | nil
        }

  @primary_key false
  typed_schema "signet_orders" do
    field(:outputs_witness_hash, Hash.Full, primary_key: true)
    field(:deadline, :integer)
    field(:block_number, :integer)
    field(:transaction_hash, Hash.Full)
    field(:log_index, :integer)
    field(:inputs_json, :string)
    field(:outputs_json, :string)
    field(:sweep_recipient, Hash.Address)
    field(:sweep_token, Hash.Address)
    field(:sweep_amount, Wei)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = order, attrs \\ %{}) do
    order
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:outputs_witness_hash)
  end

  @doc """
  Shared result key used by import runners to return inserted Signet orders.
  """
  @spec insert_result_key() :: atom()
  def insert_result_key, do: @insert_result_key
end
