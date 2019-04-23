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
    # red
    "\e[94m" => "136, 0, 0"
  }

  def highlight_decompiled_code(code) do
    {_, result} =
      @colors
      |> Enum.reduce(code, fn {symbol, rgb}, acc ->
        String.replace(acc, symbol, "<span style=\"color:rgb(#{rgb})\">")
      end)
      |> String.replace("\e[1m", "<span style=\"font-weight:bold\">")
      |> String.replace("»", "&raquo;")
      |> String.replace("\e[0m", "</span>")
      |> String.split(~r/\<span style=.*?\)"\>|\<\/span\>/, include_captures: true, trim: true)
      |> Enum.reduce({"", []}, fn part, {style, acc} ->
        new_style =
          cond do
            String.contains?(part, "<span style") -> part
            part == "</span>" -> ""
            true -> style
          end

        new_part = new_part(part, new_style)

        {new_style, [new_part | acc]}
      end)

    result
    |> Enum.reduce("", fn part, acc ->
      part <> acc
    end)
    |> add_line_numbers()
  end

  def sort_contracts_by_version(decompiled_contracts) do
    decompiled_contracts
    |> Enum.sort_by(& &1.decompiler_version)
    |> Enum.reverse()
  end

  defp add_line_numbers(code) do
    code
    |> String.split("\n")
    |> Enum.reduce("", fn line, acc ->
      acc <> "<code>#{line}</code>\n"
    end)
  end

  defp new_part(part, new_style) do
    cond do
      part == "" ->
        ""

      part == "</span>" ->
        ""

      part == new_style ->
        ""

      new_style == "" ->
        part

      true ->
        result =
          part
          |> String.split("\n")
          |> Enum.reduce("", fn p, a ->
            a <> new_style <> p <> "</span>\n"
          end)

        if String.ends_with?(part, "\n") do
          result
        else
          String.slice(result, 0..-2)
        end
    end
  end
end
