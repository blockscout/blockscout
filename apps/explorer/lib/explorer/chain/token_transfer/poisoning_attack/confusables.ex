# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.Confusables do
  @moduledoc """
  Folds the letters of other scripts that look like Latin letters onto them,
  so that an asset name spelt with homoglyphs compares equal to the one it
  imitates: a `USDT` whose `T` is the Cyrillic Te, whose `S` is the Cyrillic
  Dze, is the fake the `name_imitation` rule is after.

  The table is a hand-picked subset of the Unicode confusables data, limited
  to whole letters of the scripts seen in such fakes — Cyrillic, Greek,
  Cherokee, Canadian Aboriginal syllabics and a few Latin variants — mapped
  onto the lowercase Latin letter they resemble. Letters of those scripts
  that resemble nothing Latin are left alone. The table is applied to
  lowercase text; the uppercase letters listed here stand for both cases.
  """

  # {confusable letter, Latin letter it resembles}; written as escapes to keep
  # the source ASCII, the comment gives the character
  @letters [
    # Cyrillic, both cases
    {"А", "a"},
    {"В", "b"},
    {"Е", "e"},
    {"К", "k"},
    {"М", "m"},
    {"Н", "h"},
    {"О", "o"},
    {"Р", "p"},
    {"С", "c"},
    {"Т", "t"},
    {"У", "y"},
    {"Х", "x"},
    {"Ѕ", "s"},
    {"І", "i"},
    {"Ј", "j"},
    {"Һ", "h"},
    {"Ԁ", "d"},
    {"Ԛ", "q"},
    {"Ԝ", "w"},
    {"Ѵ", "v"},
    {"Ԍ", "g"},
    {"а", "a"},
    {"е", "e"},
    {"о", "o"},
    {"р", "p"},
    {"с", "c"},
    {"у", "y"},
    {"х", "x"},
    {"ѕ", "s"},
    {"і", "i"},
    {"ј", "j"},
    {"һ", "h"},
    {"ԁ", "d"},
    {"ԛ", "q"},
    {"ԝ", "w"},
    {"ѵ", "v"},
    {"ԍ", "g"},
    # Greek, both cases
    {"Α", "a"},
    {"Β", "b"},
    {"Ε", "e"},
    {"Ζ", "z"},
    {"Η", "h"},
    {"Ι", "i"},
    {"Κ", "k"},
    {"Μ", "m"},
    {"Ν", "n"},
    {"Ο", "o"},
    {"Ρ", "p"},
    {"Τ", "t"},
    {"Υ", "y"},
    {"Χ", "x"},
    {"Ϲ", "c"},
    {"α", "a"},
    {"ι", "i"},
    {"κ", "k"},
    {"ν", "v"},
    {"ο", "o"},
    {"ρ", "p"},
    {"τ", "t"},
    {"υ", "u"},
    {"ϲ", "c"},
    {"ϳ", "j"},
    # Cherokee
    {"Ꭰ", "d"},
    {"Ꭱ", "r"},
    {"Ꭲ", "t"},
    {"Ꭹ", "y"},
    {"Ꭺ", "a"},
    {"Ꭻ", "j"},
    {"Ꭼ", "e"},
    {"Ꮃ", "w"},
    {"Ꮇ", "m"},
    {"Ꮋ", "h"},
    {"Ꮎ", "o"},
    {"Ꮐ", "g"},
    {"Ꮓ", "z"},
    {"Ꮟ", "b"},
    {"Ꮢ", "r"},
    {"Ꮩ", "v"},
    {"Ꮪ", "s"},
    {"Ꮮ", "l"},
    {"Ꮯ", "c"},
    {"Ꮲ", "p"},
    {"Ꮶ", "k"},
    # Canadian Aboriginal syllabics
    {"ᐯ", "v"},
    {"ᑌ", "u"},
    {"ᑎ", "n"},
    {"ᑕ", "c"},
    {"ᑫ", "q"},
    {"ᑭ", "p"},
    {"ᒍ", "j"},
    {"ᒪ", "l"},
    {"ᕼ", "h"},
    {"ᖇ", "r"},
    {"ᖴ", "f"},
    {"ᗅ", "a"},
    {"ᗞ", "d"},
    {"ᗯ", "w"},
    {"ᗰ", "m"},
    {"ᗷ", "b"},
    {"᙭", "x"},
    {"ᕮ", "e"},
    # Latin letters outside the basic alphabet
    {"ı", "i"},
    {"ȷ", "j"},
    {"ɑ", "a"},
    {"ɡ", "g"},
    {"ɩ", "i"},
    {"ꜱ", "s"}
  ]

  @table Map.new(@letters, fn {letter, latin} ->
           [codepoint] = letter |> String.downcase() |> String.to_charlist()
           {codepoint, latin}
         end)

  @doc """
  Replaces every letter of `text` that resembles a Latin letter with that
  letter. `text` is expected lowercase; nothing else is touched.

      iex> skeleton("\\u0442\\u0435\\u0442\\u043D\\u0435r")
      "tether"
  """
  @spec skeleton(String.t()) :: String.t()
  def skeleton(text) when is_binary(text) do
    for <<codepoint::utf8 <- text>>, into: "" do
      Map.get(@table, codepoint) || <<codepoint::utf8>>
    end
  end
end
