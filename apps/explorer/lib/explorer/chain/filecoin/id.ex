defmodule Explorer.Chain.Filecoin.IDAddress do
  @moduledoc """
  Handles Filecoin ID addresses, wrapping the `NativeAddress` type.
  """

  alias Explorer.Chain.Filecoin.NativeAddress
  alias Poison.Encoder.BitString

  require Integer

  defstruct ~w(value)a

  @protocol_indicator 0

  use Ecto.Type

  @type t :: %__MODULE__{value: binary()}

  @impl Ecto.Type
  @spec type() :: :binary
  def type, do: :binary

  defp to_native_address(%__MODULE__{value: value}) do
    %NativeAddress{
      protocol_indicator: @protocol_indicator,
      payload: value
    }
  end

  @doc """
  Casts a binary string to a `Explorer.Chain.Filecoin.IDAddress`.

  ## Examples

      iex> Explorer.Chain.Filecoin.IDAddress.cast("f01729")
      {:ok, %Explorer.Chain.Filecoin.IDAddress{value: <<193, 13>>}}

      iex> Explorer.Chain.Filecoin.IDAddress.cast(%Explorer.Chain.Filecoin.IDAddress{value: <<193, 13>>})
      {:ok, %Explorer.Chain.Filecoin.IDAddress{value: <<193, 13>>}}

      iex> Explorer.Chain.Filecoin.IDAddress.cast("invalid")
      :error
  """
  @impl Ecto.Type
  def cast(address_string) when is_binary(address_string) do
    address_string
    |> NativeAddress.cast()
    |> case do
      {:ok,
       %NativeAddress{
         protocol_indicator: @protocol_indicator,
         payload: value
       }} ->
        {:ok, %__MODULE__{value: value}}

      _ ->
        :error
    end
  end

  @impl Ecto.Type
  def cast(%__MODULE__{} = address), do: {:ok, address}

  @impl Ecto.Type
  def cast(_), do: :error

  @doc """
  Dumps an `Explorer.Chain.Filecoin.IDAddress` to its binary representation.

  ## Examples

      iex> address = %Explorer.Chain.Filecoin.IDAddress{value: <<193, 13>>}
      iex> Explorer.Chain.Filecoin.IDAddress.dump(address)
      {:ok, <<0, 193, 13>>}

      iex> Explorer.Chain.Filecoin.IDAddress.dump("invalid")
      :error
  """
  @impl Ecto.Type
  def dump(%__MODULE__{} = address) do
    address
    |> to_native_address()
    |> NativeAddress.dump()
  end

  def dump(_), do: :error

  @doc """
  Loads a binary representation of an `Explorer.Chain.Filecoin.IDAddress`.

  ## Examples

      iex> Explorer.Chain.Filecoin.IDAddress.load(<<0, 193, 13>>)
      {:ok, %Explorer.Chain.Filecoin.IDAddress{value: <<193, 13>>}}

      iex> Explorer.Chain.Filecoin.IDAddress.load("invalid")
      :error
  """
  @impl Ecto.Type
  def load(bytes) when is_binary(bytes) do
    bytes
    |> NativeAddress.load()
    |> case do
      {:ok,
       %NativeAddress{
         protocol_indicator: @protocol_indicator,
         payload: value
       }} ->
        {:ok, %__MODULE__{value: value}}

      _ ->
        :error
    end
  end

  def load(_), do: :error

  @doc """
  Converts an `Explorer.Chain.Filecoin.IDAddress` to its string representation.

  ## Examples

      iex> address = %Explorer.Chain.Filecoin.IDAddress{value: <<193, 13>>}
      iex> Explorer.Chain.Filecoin.IDAddress.to_string(address)
      "f01729"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = address) do
    address
    |> to_native_address()
    |> NativeAddress.to_string()
  end

  defimpl String.Chars do
    def to_string(address) do
      @for.to_string(address)
    end
  end

  defimpl Poison.Encoder do
    def encode(address, options) do
      address
      |> to_string()
      |> BitString.encode(options)
    end
  end

  defimpl Jason.Encoder do
    alias Jason.Encode

    def encode(address, opts) do
      address
      |> to_string()
      |> Encode.string(opts)
    end
  end
end
