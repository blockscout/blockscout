defmodule Explorer.Chain.VLX do
  @alphabet ~c(123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz)

  def eth_to_vlx(address) do
    try do
      eth_to_vlx!(address)
    rescue
      e -> {:error, e}
    else
      res -> {:ok, res}
    end
  end

  def vlx_to_eth(address) do
    try do
      vlx_to_eth!(address)
    rescue
      e -> {:error, e}
    else
      res -> {:ok, res}
    end
  end

  @doc """
  Encodes the given ethereum address to vlx format.
  """
  def eth_to_vlx!(address) do
    stripped_address =
      address
      |> String.trim_leading("0x")
      |> case do
        addr when byte_size(addr) == 40 -> String.downcase addr
        _ -> raise ArgumentError, message: "Invalid address prefix or length"
      end

    checksum =
      stripped_address
      |> sha256
      |> sha256
      |> String.slice(0, 8)

    parsed_address =
      stripped_address <> checksum
      |> Integer.parse(16)

    case parsed_address do
      {x, ""} when is_integer(x) -> nil
      _ -> raise ArgumentError, message: "Invalid address format"
    end

    encoded_address =
      parsed_address
      |> elem(0)
      |> b58_encode()
      |> String.pad_leading(33, "1")

    "V" <> encoded_address
  end

  @doc """
  Decodes the given vlx address to ethereum format.
  """
  def vlx_to_eth!(address) do
    decoded_address =
      address
      |> String.trim_leading("V")
      |> b58_decode()
      |> Integer.to_string(16)
      |> String.downcase      
      |> String.pad_leading(48, "0")

    strings = Regex.run(~r/([0-9abcdef]+)([0-9abcdef]{8})$/, decoded_address)

    [_, short_address, extracted_checksum] =
      case strings do
        list when length(list) == 3 -> list
        _ -> raise ArgumentError, message: "Invalid address"
      end

    checksum = 
      short_address
      |> sha256
      |> sha256
      |> String.slice(0, 8)      

    if extracted_checksum != checksum do
      raise ArgumentError, message: "Invalid checksum"
    end

    ("0x" <> short_address) |> String.downcase()
  end

  defp b58_encode(x), do: _encode(x, [])

  defp b58_decode(enc), do: _decode(enc |> to_charlist, 0)

  defp _encode(0, []), do: [@alphabet |> hd] |> to_string
  defp _encode(0, acc), do: acc |> to_string

  defp _encode(x, acc) do
    _encode(div(x, 58), [Enum.at(@alphabet, rem(x, 58)) | acc])
  end

  defp _decode([], acc), do: acc

  defp _decode([c | cs], acc) do
    _decode(cs, acc * 58 + Enum.find_index(@alphabet, &(&1 == c)))
  end

  defp sha256(x) do
    :crypto.hash(:sha256, x) 
    |> Base.encode16(case: :lower)
  end
end
