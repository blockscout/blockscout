defmodule Explorer.Chain.Celo.TransactionStats do
  @moduledoc """
    Modelling arbitrary rows in a table to designed optimise transaction statistic lookups
  """
  require Logger

  alias __MODULE__
  alias Explorer.Repo
  use Explorer.Schema
  import Ecto.Query

  @type t :: %__MODULE__{
          stat_type: String.t(),
          value: non_neg_integer()
        }

  @attrs ~w(stat_type value)a
  @required_attrs ~w(stat_type value)a

  @primary_key false
  schema "celo_transaction_stats" do
    field(:stat_type, :string)
    field(:value, :decimal)
  end

  def changeset(%__MODULE__{} = item, attrs) do
    item
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
  end

  @tx_count_type "total_transaction_count"
  def transaction_count do
    %TransactionStats{value: count} =
      TransactionStats
      |> where([t], t.stat_type == @tx_count_type)
      |> Repo.one()

    case count do
      %Decimal{} ->
        count |> Decimal.to_integer()

      n ->
        n
    end
  end

  @total_gas_type "total_gas_used"
  def total_gas do
    %TransactionStats{value: total_gas} =
      TransactionStats
      |> where([t], t.stat_type == @total_gas_type)
      |> Repo.one()

    case total_gas do
      %Decimal{} ->
        total_gas |> Decimal.to_integer()

      n ->
        n
    end
  end
end
