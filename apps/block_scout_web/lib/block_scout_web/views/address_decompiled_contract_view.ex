defmodule BlockScoutWeb.AddressDecompiledContractView do
  use BlockScoutWeb, :view

  @colors %{
    "\e[95m" => "136, 0, 0",
    # red
    "\e[91m" => "236, 89, 58",
    # gray
    "\e[38;5;8m" => "111, 110, 111",
    # green
    "\e[32m" => "57, 115, 0",
    # yellowgreen
    "\e[93m" => "57, 115, 0",
    # yellow
    "\e[92m" => "119, 232, 81",
    # purple
    "\e[94m" => "136, 0, 0"
  }

  def highlight_decompiled_code(code) do
    @colors
    |> Enum.reduce(code, fn {symbol, rgb}, acc ->
      String.replace(acc, symbol, "<span style=\"color:rgb(#{rgb})\">")
    end)
    |> String.replace("\e[1m", "<span style=\"font-weight:bold\">")
    |> String.replace("»", "&raquo;")
    |> String.replace("\e[0m", "</span>")
    |> add_line_numbers()
  end

  defp add_line_numbers(code) do
    code
    |> String.split("\n")
    |> Enum.reduce("", fn line, acc ->
      acc <> "<code>#{line}</code>\n"
    end)
  end
end
