defmodule BlockScoutWeb.AddressDecompiledContractView do
  use BlockScoutWeb, :view

  @colors %{
    "\e[95m" => "",
    # red
    "\e[91m" => "",
    # gray
    "\e[38;5;8m" => "<span style=\"color:rgb(111, 110, 111)\">",
    # green
    "\e[32m" => "",
    # yellowgreen
    "\e[93m" => "",
    # yellow
    "\e[92m" => "",
    # red
    "\e[94m" => ""
  }

  @reserved_words [
    "def",
    "require",
    "revert",
    "return",
    "assembly",
    "memory",
    "payable",
    "public",
    "view",
    "pure",
    "returns",
    "internal"
  ]

  def highlight_decompiled_code(code) do
    {_, result} =
      @colors
      |> Enum.reduce(code, fn {symbol, rgb}, acc ->
        String.replace(acc, symbol, rgb)
      end)
      |> String.replace("\e[1m", "<span style=\"font-weight:bold\">")
      |> String.replace("»", "&raquo;")
      |> String.replace("\e[0m", "</span>")
      |> String.split(~r/\<span style=.*?\)"\>|\<\/span\>/, include_captures: true, trim: true)
      |> add_styles_to_every_line()

    result
    |> Enum.reduce("", fn part, acc ->
      part <> acc
    end)
    |> add_styles_to_reserved_words()
    |> add_line_numbers()
  end

  defp add_styles_to_every_line(lines) do
    lines
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
  end

  defp add_styles_to_reserved_words(code) do
    code
    |> String.split("\n")
    |> Enum.map(fn line ->
      parts =
        line
        |> String.split(~r/def|require|revert|return|assembly|memory|payable|public|view|pure|returns|internal|#/,
          include_captures: true
        )

      comment_position = Enum.find_index(parts, fn part -> part == "#" end)

      parts
      |> Enum.with_index()
      |> Enum.map(fn {el, index} ->
        if (is_nil(comment_position) || comment_position > index) && el in @reserved_words do
          "<span class=\"hljs-keyword\">" <> el <> "</span>"
        else
          el
        end
      end)
      |> Enum.reduce("", fn el, acc ->
        acc <> el
      end)
    end)
    |> Enum.reduce("", fn el, acc ->
      acc <> el <> "\n"
    end)
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
        part
        |> String.split("\n")
        |> Enum.reduce("", fn p, a ->
          a <> new_style <> p <> "</span>\n"
        end)
        |> String.slice(0..-2)
    end
  end
end
