defmodule BlockScoutWeb.AddressDecompiledContractView do
  use BlockScoutWeb, :view

  @colors %{
    "\033[95m" => "235, 97, 247",
    "\033[91m" => "236, 89, 58",
    "\033[38;5;8m" => "111, 110, 111",
    "\033[32m" => "107, 194, 76",
    "\033[93m" => "239, 236, 84",
    "\033[92m" => "119, 232, 81",
    "\033[94m" => "184, 90, 190"
  }

  def highlight_decompiled_code(code) do
    @colors
    |> Enum.reduce(code, fn {symbol, rgb}, acc ->
      String.replace(acc, symbol, "<span style=\"color:rgb(#{rgb})\">")
    end)
    |> String.replace("\033[1m", "<span style=\"font-weight:bold\">")
    |> String.replace("»", "&raquo;")
    |> String.replace("\033[0m", "</span>")
  end
end
