defmodule Explorer.Chain.Token.FiatValue do
  @moduledoc """
  Represents money values, used to hide the value if there is a chance that the value is not relevant.
  """

  use Ecto.Type

  alias Explorer.Market

  @type t :: Decimal.t() | nil

  @impl Ecto.Type
  def type, do: :decimal

  @impl Ecto.Type
  def cast(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} ->
        {:ok, decimal}

      _ ->
        :error
    end
  end

  @impl Ecto.Type
  def cast(value) when is_integer(value) do
    {:ok, Decimal.new(value)}
  end

  @impl Ecto.Type
  def cast(value) when is_float(value) do
    {:ok, Decimal.from_float(value)}
  end

  @impl Ecto.Type
  def cast(%Decimal{} = decimal) do
    {:ok, decimal}
  end

  @impl Ecto.Type
  def cast(_), do: :error

  @impl Ecto.Type
  def dump(%Decimal{} = decimal) do
    {:ok, decimal}
  end

  @impl Ecto.Type
  def dump(_), do: :error

  @impl Ecto.Type
  def load(%Decimal{} = decimal) do
    if Market.token_fetcher_enabled?() do
      {:ok, decimal}
    else
      {:ok, nil}
    end
  end
end
