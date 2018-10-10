defmodule BlockScoutWeb.BlockView do
  use BlockScoutWeb, :view

  import Math.Enum, only: [mean: 1]

  alias Explorer.Chain.{Block, Wei}

  @dialyzer :no_match

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

  def block_type(%Block{consensus: false, nephews: []}), do: "Reorg"
  def block_type(%Block{consensus: false}), do: "Uncle"
  def block_type(_block), do: "Block"

  @doc """
  Work-around for spec issue in `Cldr.Unit.to_string!/1`
  """
  def cldr_unit_to_string!(unit) do
    # We do this to trick Dialyzer to not complain about non-local returns caused by bug in Cldr.Unit.to_string! spec
    case :erlang.phash2(1, 1) do
      0 ->
        Cldr.Unit.to_string!(unit)

      1 ->
        # does not occur
        ""
    end
  end

  def formatted_gas(gas, format \\ []) do
    Cldr.Number.to_string!(gas, format)
  end

  def formatted_timestamp(%Block{timestamp: timestamp}) do
    Timex.format!(timestamp, "%b-%d-%Y %H:%M:%S %p %Z", :strftime)
  end
end
