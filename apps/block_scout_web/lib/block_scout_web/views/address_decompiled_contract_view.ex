defmodule BlockScoutWeb.AddressDecompiledContractView do
  use BlockScoutWeb, :view

  @colors %{
    "\e[95m" => "235, 97, 247",
    "\e[91m" => "236, 89, 58",
    "\e[38;5;8m" => "111, 110, 111",
    "\e[32m" => "107, 194, 76",
    "\e[93m" => "239, 236, 84",
    "\e[92m" => "119, 232, 81",
    "\e[94m" => "184, 90, 190"
  }

  def highlight_decompiled_code(code) do
    @colors
    |> Enum.reduce(code, fn {symbol, rgb}, acc ->
      String.replace(acc, symbol, "<span style=\"color:rgb(#{rgb})\">")
    end)
    |> String.replace("\e[1m", "<span style=\"font-weight:bold\">")
    |> String.replace("»", "&raquo;")
    |> String.replace("\e[0m", "</span>")
  end
end
