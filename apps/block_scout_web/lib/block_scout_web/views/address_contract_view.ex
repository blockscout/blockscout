defmodule BlockScoutWeb.AddressContractView do
  use BlockScoutWeb, :view

  def format_smart_contract_abi(abi), do: Poison.encode!(abi, pretty: false)

  @doc """
  Returns the correct format for the optimization text.

    iex> BlockScoutWeb.AddressContractView.format_optimization_text(true)
    "true"

    iex> BlockScoutWeb.AddressContractView.format_optimization_text(false)
    "false"
  """
  def format_optimization_text(true), do: gettext("true")
  def format_optimization_text(false), do: gettext("false")

  def contract_lines_with_index(contract_source_code) do
    contract_lines = String.split(contract_source_code, "\n")

    max_digits =
      contract_lines
      |> Enum.count()
      |> Integer.digits()
      |> Enum.count()

    contract_lines
    |> Enum.with_index(1)
    |> Enum.map(fn {value, line} ->
      {value, String.pad_leading(to_string(line), max_digits, " ")}
    end)
  end
end
