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

  @comment_start "#"

  @reserved_words_types [
    "var",
    "bool",
    "string",
    "int",
    "uint",
    "int8",
    "uint8",
    "int16",
    "uint16",
    "int24",
    "uint24",
    "int32",
    "uint32",
    "int40",
    "uint40",
    "int48",
    "uint48",
    "int56",
    "uint56",
    "int64",
    "uint64",
    "int72",
    "uint72",
    "int80",
    "uint80",
    "int88",
    "uint88",
    "int96",
    "uint96",
    "int104",
    "uint104",
    "int112",
    "uint112",
    "int120",
    "uint120",
    "int128",
    "uint128",
    "int136",
    "uint136",
    "int144",
    "uint144",
    "int152",
    "uint152",
    "int160",
    "uint160",
    "int168",
    "uint168",
    "int176",
    "uint176",
    "int184",
    "uint184",
    "int192",
    "uint192",
    "int200",
    "uint200",
    "int208",
    "uint208",
    "int216",
    "uint216",
    "int224",
    "uint224",
    "int232",
    "uint232",
    "int240",
    "uint240",
    "int248",
    "uint248",
    "int256",
    "uint256",
    "byte",
    "bytes",
    "bytes1",
    "bytes2",
    "bytes3",
    "bytes4",
    "bytes5",
    "bytes6",
    "bytes7",
    "bytes8",
    "bytes9",
    "bytes10",
    "bytes11",
    "bytes12",
    "bytes13",
    "bytes14",
    "bytes15",
    "bytes16",
    "bytes17",
    "bytes18",
    "bytes19",
    "bytes20",
    "bytes21",
    "bytes22",
    "bytes23",
    "bytes24",
    "bytes25",
    "bytes26",
    "bytes27",
    "bytes28",
    "bytes29",
    "bytes30",
    "bytes31",
    "bytes32",
    "true",
    "false",
    "enum",
    "struct",
    "mapping",
    "address"
  ]

  @reserved_words_keywords [
    "def",
    "require",
    "revert",
    "return",
    "assembly",
    "memory",
    "mem"
  ]

  @modifiers [
    "payable",
    "public",
    "view",
    "pure",
    "returns",
    "internal"
  ]

  @reserved_words @reserved_words_keywords ++ @reserved_words_types

  @reserved_words_regexp ([@comment_start | @reserved_words] ++ @modifiers)
                         |> Enum.reduce("", fn el, acc -> acc <> "|" <> el end)
                         |> Regex.compile!()

  def highlight_decompiled_code(code) do
    {_, result} =
      @colors
      |> Enum.reduce(code, fn {symbol, rgb}, acc ->
        String.replace(acc, symbol, rgb)
      end)
      |> String.replace("\e[1m", "<span style=\"font-weight:bold\">")
      |> String.replace("»", "&raquo;")
      |> String.replace("\e[0m", "</span>")
      |> String.split(~r/\<span style=.*?\)"\>|\<span style=\"font-weight:bold\"\>|\<\/span\>/,
        include_captures: true,
        trim: true
      )
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
      add_styles_to_line(line)
    end)
    |> Enum.reduce("", fn el, acc ->
      acc <> el <> "\n"
    end)
  end

  defp add_styles_to_line(line) do
    parts =
      line
      |> String.split(@reserved_words_regexp,
        include_captures: true
      )

    comment_position = Enum.find_index(parts, fn part -> part == "#" end)

    parts
    |> Enum.with_index()
    |> Enum.map(fn {el, index} ->
      cond do
        !(is_nil(comment_position) || comment_position > index) -> el
        el in @reserved_words -> "<span class=\"hljs-keyword\">" <> el <> "</span>"
        el in @modifiers -> "<span class=\"hljs-title\">" <> el <> "</span>"
        true -> el
      end
    end)
    |> Enum.reduce("", fn el, acc ->
      acc <> el
    end)
  end

  def last_decompiled_contract_version(decompiled_contracts) when is_nil(decompiled_contracts), do: nil

  def last_decompiled_contract_version(decompiled_contracts) when decompiled_contracts == [], do: nil

  def last_decompiled_contract_version(decompiled_contracts) do
    Enum.max_by(decompiled_contracts, & &1.decompiler_version)
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
