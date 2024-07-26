defmodule Explorer.Helper do
  @moduledoc """
  Auxiliary common functions.
  """

  alias ABI.TypeDecoder
  alias Explorer.Chain
  alias Explorer.Chain.Data

  import Ecto.Query, only: [where: 3]
  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  @max_safe_integer round(:math.pow(2, 63)) - 1

  @spec decode_data(binary() | map(), list()) :: list() | nil
  def decode_data("0x", types) do
    for _ <- types, do: nil
  end

  def decode_data("0x" <> encoded_data, types) do
    decode_data(encoded_data, types)
  end

  def decode_data(%Data{} = data, types) do
    data
    |> Data.to_string()
    |> decode_data(types)
  end

  def decode_data(encoded_data, types) do
    encoded_data
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

  @doc """
  Takes an Ethereum hash and converts it to a standard 20-byte address by
  truncating the leading zeroes. If the input is `nil`, it returns the burn
  address.

  ## Parameters
  - `address_hash` (`EthereumJSONRPC.hash()` | `nil`): The full address hash to
    be truncated, or `nil`.

  ## Returns
  - `EthereumJSONRPC.address()`: The truncated address or the burn address if
    the input is `nil`.

  ## Examples

      iex> truncate_address_hash("0x000000000000000000000000abcdef1234567890abcdef1234567890abcdef")
      "0xabcdef1234567890abcdef1234567890abcdef"

      iex> truncate_address_hash(nil)
      "0x0000000000000000000000000000000000000000"
  """
  @spec truncate_address_hash(EthereumJSONRPC.hash() | nil) :: EthereumJSONRPC.address()
  def truncate_address_hash(address_hash)

  def truncate_address_hash(nil), do: burn_address_hash_string()

  def truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
  end

  def parse_integer(integer_string) when is_binary(integer_string) do
    case Integer.parse(integer_string) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  def parse_integer(value) when is_integer(value) do
    value
  end

  def parse_integer(_integer_string), do: nil

  @doc """
  Parses number from hex string or decimal number string
  """
  @spec parse_number(binary() | nil) :: integer() | nil
  def parse_number(nil), do: nil

  def parse_number(number) when is_integer(number) do
    number
  end

  def parse_number("0x" <> hex_number) do
    {number, ""} = Integer.parse(hex_number, 16)

    number
  end

  def parse_number(""), do: 0

  def parse_number(string_number) do
    {number, ""} = Integer.parse(string_number, 10)

    number
  end

  @doc """
    Converts a string to an integer, ensuring it's non-negative and within the
    acceptable range for database insertion.

    ## Examples

        iex> safe_parse_non_negative_integer("0")
        {:ok, 0}

        iex> safe_parse_non_negative_integer("-1")
        {:error, :negative_integer}

        iex> safe_parse_non_negative_integer("27606393966689717254124294199939478533331961967491413693980084341759630764504")
        {:error, :too_big_integer}
  """
  def safe_parse_non_negative_integer(string) do
    case Integer.parse(string) do
      {num, ""} ->
        case num do
          _ when num > @max_safe_integer -> {:error, :too_big_integer}
          _ when num < 0 -> {:error, :negative_integer}
          _ -> {:ok, num}
        end

      _ ->
        {:error, :invalid_integer}
    end
  end

  @doc """
    Function to preload a `struct` for each element of the `list`.
    You should specify a primary key for a `struct` in `references_field`,
    and the list element's foreign key in `foreign_key_field`.
    Results will be placed to `preload_field`
  """
  @spec custom_preload(list(map()), keyword(), atom(), atom(), atom(), atom()) :: list()
  def custom_preload(list, options, struct, foreign_key_field, references_field, preload_field) do
    to_fetch_from_db = list |> Enum.map(& &1[foreign_key_field]) |> Enum.uniq()

    associated_elements =
      struct
      |> where([t], field(t, ^references_field) in ^to_fetch_from_db)
      |> Chain.select_repo(options).all()
      |> Enum.reduce(%{}, fn el, acc -> Map.put(acc, Map.from_struct(el)[references_field], el) end)

    Enum.map(list, fn el -> Map.put(el, preload_field, associated_elements[el[foreign_key_field]]) end)
  end

  @doc """
  Decode json
  """
  @spec decode_json(any()) :: map() | list() | nil
  def decode_json(data, nft? \\ false)

  def decode_json(nil, _), do: nil

  def decode_json(data, nft?) do
    if String.valid?(data) do
      safe_decode_json(data, nft?)
    else
      data
      |> :unicode.characters_to_binary(:latin1)
      |> safe_decode_json(nft?)
    end
  end

  defp safe_decode_json(data, nft?) do
    case Jason.decode(data) do
      {:ok, decoded} -> decoded
      _ -> if nft?, do: {:error, data}, else: %{error: data}
    end
  end

  @doc """
  Checks if input is a valid URL
  """
  @spec validate_url(String.t() | nil) :: {:ok, String.t()} | :error
  def validate_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: nil} -> :error
      _ -> {:ok, url}
    end
  end

  def validate_url(_), do: :error

  @doc """
    Validate url
  """
  @spec valid_url?(String.t()) :: boolean()
  def valid_url?(string) when is_binary(string) do
    uri = URI.parse(string)

    !is_nil(uri.scheme) && !is_nil(uri.host)
  end

  def valid_url?(_), do: false

  @doc """
  Compare two values and returns either :lt, :eq or :gt.

  Please be careful: this function compares arguments using `<` and `>`,
  hence it should not be used to compare structures (for instance %DateTime{} or %Decimal{}).
  """
  @spec compare(term(), term()) :: :lt | :eq | :gt
  def compare(a, b) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true -> :eq
    end
  end
end
