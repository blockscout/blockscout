defmodule Utils.JSON do
  @moduledoc """
  Facade for Elixir's built-in JSON module, providing Jason-compatible API.

  This module abstracts the internal JSON library implementation so that code
  does not directly depend on Jason or Poison. All encoding/decoding operations
  flow through this facade, enabling future library swaps without widespread refactoring.

  Features:
  - Encoding: `encode!/2`, `encode_to_iodata!/2`, `encode/2`
  - Decoding: `decode!/2`, `decode/2`, with support for atom keys
  - Pretty-printing: deterministic JSON formatting with customizable options
  - Error handling: exceptions and tuples with consistent structure
  """

  @type option :: {:pretty, boolean()} | {:keys, :atoms | :strings}
  @type decode_option :: {:keys, :atoms | :strings}

  @doc """
  Encodes a term to JSON string.

  Options:
    - `:pretty` (boolean) - if true, formats with indentation (default: false)
    - `:space` (non_neg_integer) - spaces per indent level when pretty=true (default: 2)

  Raises on encoding errors.
  """
  @spec encode!(term(), [option()]) :: binary()
  def encode!(term, options \\ []) do
    pretty = Keyword.get(options, :pretty, false)
    result = JSON.encode!(term)

    if pretty do
      pretty_print(result, Keyword.get(options, :space, 2))
    else
      result
    end
  end

  @doc """
  Encodes a term to iodata (efficient for I/O operations).

  Options:
    - `:pretty` (boolean) - if true, formats with indentation (default: false)
    - `:space` (non_neg_integer) - spaces per indent level when pretty=true (default: 2)

  Raises on encoding errors.
  """
  @spec encode_to_iodata!(term(), [option()]) :: iodata()
  def encode_to_iodata!(term, options \\ []) do
    pretty = Keyword.get(options, :pretty, false)
    result = JSON.encode_to_iodata!(term)

    if pretty do
      pretty_print(IO.iodata_to_binary(result), Keyword.get(options, :space, 2))
    else
      result
    end
  end

  @doc """
  Encodes a term to JSON, returning {:ok, result} or {:error, reason}.

  Options: same as `encode!/2`
  """
  @spec encode(term(), [option()]) :: {:ok, binary()} | {:error, term()}
  def encode(term, options \\ []) do
    {:ok, encode!(term, options)}
  rescue
    e -> {:error, e}
  end

  @doc """
  Decodes JSON binary to a term.

  Options:
    - `:keys` - `:atoms` to convert string keys to atoms (default: `:strings`)

  Returns {:ok, term} or {:error, reason}.
  """
  @spec decode(binary(), [decode_option()]) :: {:ok, term()} | {:error, term()}
  def decode(binary, options \\ []) do
    case JSON.decode(binary) do
      {:ok, term} ->
        {:ok, maybe_atomize_keys(term, options)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Decodes JSON binary to a term, raising on error.

  Options:
    - `:keys` - `:atoms` to convert string keys to atoms (default: `:strings`)

  Raises on decode errors.
  """
  @spec decode!(binary(), [decode_option()]) :: term()
  def decode!(binary, options \\ []) do
    term = JSON.decode!(binary)
    maybe_atomize_keys(term, options)
  end

  @doc """
  Soft-decoding helper: returns term on success or a fallback value on error.
  Useful for optional JSON parsing in views.

  Options: same as `decode!/2`
  """
  @spec decode_string(binary(), [decode_option()]) :: term() | nil
  def decode_string(binary, options \\ []) do
    decode!(binary, options)
  rescue
    _ -> nil
  end

  # Private helpers

  @spec maybe_atomize_keys(term(), [decode_option()]) :: term()
  defp maybe_atomize_keys(term, options) do
    if Keyword.get(options, :keys) == :atoms do
      atomize_keys(term)
    else
      term
    end
  end

  @spec atomize_keys(term()) :: term()
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), atomize_keys(v)}
      {k, v} -> {k, atomize_keys(v)}
    end)
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(term) do
    term
  end

  @spec pretty_print(binary(), non_neg_integer()) :: binary()
  defp pretty_print(json, spaces) do
    json
    |> String.graphemes()
    |> format_graphemes(0, spaces, [])
    |> Enum.join()
  end

  @spec format_graphemes([String.t()], non_neg_integer(), non_neg_integer(), [String.t()]) :: [
          String.t()
        ]
  defp format_graphemes([], _level, _spaces, acc) do
    Enum.reverse(acc)
  end

  defp format_graphemes(["{" | rest], level, spaces, acc) do
    format_graphemes(rest, level + 1, spaces, [
      "{\n" | [String.duplicate(" ", (level + 1) * spaces) | acc]
    ])
  end

  defp format_graphemes(["}" | rest], level, spaces, acc) do
    new_level = max(0, level - 1)

    format_graphemes(rest, new_level, spaces, [
      "}" | ["\n" | [String.duplicate(" ", new_level * spaces) | acc]]
    ])
  end

  defp format_graphemes(["[" | rest], level, spaces, acc) do
    format_graphemes(rest, level + 1, spaces, [
      "[\n" | [String.duplicate(" ", (level + 1) * spaces) | acc]
    ])
  end

  defp format_graphemes(["]" | rest], level, spaces, acc) do
    new_level = max(0, level - 1)

    format_graphemes(rest, new_level, spaces, [
      "]" | ["\n" | [String.duplicate(" ", new_level * spaces) | acc]]
    ])
  end

  defp format_graphemes(["," | rest], level, spaces, acc) do
    format_graphemes(rest, level, spaces, [
      ",\n" | [String.duplicate(" ", level * spaces) | acc]
    ])
  end

  defp format_graphemes([":" | rest], level, spaces, acc) do
    format_graphemes(rest, level, spaces, [": " | acc])
  end

  defp format_graphemes([char | rest], level, spaces, acc) when char in [" ", "\n", "\t"] do
    # Skip whitespace in compact JSON
    format_graphemes(rest, level, spaces, acc)
  end

  defp format_graphemes([char | rest], level, spaces, acc) do
    format_graphemes(rest, level, spaces, [char | acc])
  end
end
