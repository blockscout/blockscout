defmodule Explorer.Chain.Receipt do
  @moduledoc "Captures a Web3 Transaction Receipt."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Log, Transaction}

  @optional_attrs ~w(transaction_hash)a
  @required_attrs ~w(cumulative_gas_used gas_used status index)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  schema "receipts" do
    field(:cumulative_gas_used, :decimal)
    field(:gas_used, :decimal)
    field(:status, :integer)
    field(:index, :integer)

    belongs_to(:transaction, Transaction, foreign_key: :transaction_hash, references: :hash, type: Hash.Full)
    has_many(:logs, Log)

    timestamps()
  end

  # Functions

  def changeset(%__MODULE__{} = transaction_receipt, attrs \\ %{}) do
    transaction_receipt
    |> cast(attrs, @allowed_attrs)
    |> cast_assoc(:transaction)
    |> cast_assoc(:logs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_hash)
    |> unique_constraint(:transaction_hash)
  end

  def extract(raw_receipt, transaction_hash, %{} = timestamps) do
    logs =
      raw_receipt
      |> Map.fetch!("logs")
      |> Enum.map(&extract_log(&1, timestamps))

    receipt = %{
      transaction_hash: transaction_hash,
      index: raw_receipt["transactionIndex"],
      cumulative_gas_used: raw_receipt["cumulativeGasUsed"],
      gas_used: raw_receipt["gasUsed"],
      status: raw_receipt["status"],
      inserted_at: Map.fetch!(timestamps, :inserted_at),
      updated_at: Map.fetch!(timestamps, :updated_at)
    }

    {receipt, logs}
  end

  def null, do: %__MODULE__{}

  ## Private Functions

  defp extract_log(log, %{} = timestamps) do
    # address = Address.find_or_create_by_hash(log["address"])

    %{
      # address_id: 0, # TODO
      index: log["logIndex"],
      data: log["data"],
      type: log["type"],
      first_topic: log["topics"] |> Enum.at(0),
      second_topic: log["topics"] |> Enum.at(1),
      third_topic: log["topics"] |> Enum.at(2),
      fourth_topic: log["topics"] |> Enum.at(3),
      inserted_at: Map.fetch!(timestamps, :inserted_at),
      updated_at: Map.fetch!(timestamps, :updated_at)
    }
  end
end
