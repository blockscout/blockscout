defmodule Explorer.Chain.TransactionActions do
  @moduledoc "Models transaction actions."

  use Explorer.Schema

  alias Explorer.Chain.{
    Hash,
    Transaction
  }

  @required_attrs ~w(hash protocol data type log_index)a

  @typedoc """
  * `hash` - transaction hash
  * `protocol` - name of the action protocol (see possible values for Enum of the db table field)
  * `data` - transaction action details (json formatted)
  * `type` - type of the action protocol (see possible values for Enum of the db table field)
  * `log_index` - index of the action for sorting (taken from log.index)
  """
  @type t :: %__MODULE__{
          hash: Hash.t(),
          protocol: String.t(),
          data: map(),
          type: String.t(),
          log_index: non_neg_integer()
        }

  schema "transaction_actions" do
    field(:protocol, Ecto.Enum, values: [:uniswap_v3, :"opensea_v1.1", :wrapping, :approval, :zkbob])
    field(:data, :map)

    field(:type, Ecto.Enum,
      values: [
        :mint_nft,
        :mint,
        :burn,
        :collect,
        :swap,
        :sale,
        :cancel,
        :transfer,
        :wrap,
        :unwrap,
        :approve,
        :revoke,
        :withdraw,
        :deposit
      ]
    )

    field(:log_index, :integer)

    belongs_to(:transaction, Transaction, foreign_key: :hash, references: :hash, type: Hash.Full)

    timestamps()
  end

  def changeset(%__MODULE__{} = tx_actions, attrs \\ %{}) do
    tx_actions
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:hash)
  end
end
