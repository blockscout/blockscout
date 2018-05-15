defmodule ExplorerWeb.BlockView do
  use ExplorerWeb, :view

  import Math.Enum, only: [mean: 1]

  alias Explorer.Chain.{Block, Wei}

  @dialyzer :no_match

  def age(%Block{timestamp: timestamp}) do
    Timex.from_now(timestamp)
  end

  def average_gas_price(%Block{transactions: transactions}) do
    average =
      transactions
      |> Enum.map(&Decimal.to_float(Wei.to(&1.gas_price, :gwei)))
      |> mean()
      |> Kernel.||(0)
      |> Cldr.Number.to_string!()

    unit_text = gettext("Gwei")

    "#{average} #{unit_text}"
  end

  def formatted_timestamp(%Block{timestamp: timestamp}) do
    Timex.format!(timestamp, "%b-%d-%Y %H:%M:%S %p %Z", :strftime)
  end
end
