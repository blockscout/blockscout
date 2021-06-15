defmodule Explorer.Chain.MethodIdentifier do
  @moduledoc """
  The first four bytes of the [KECCAK-256](https://en.wikipedia.org/wiki/SHA-3) hash of a contract method or event.

  Represented in the database as a 4 byte integer, decodes into a 4 byte bitstring
  """

  use Ecto.Type

  @type t :: binary

  @impl true
  def type, do: :integer

  @impl true
  @spec load(integer) :: {:ok, t()}
  def load(value) do
    {:ok, <<value::integer-signed-32>>}
  end

  @impl true
  @spec cast(binary) :: {:ok, t()} | :error
  def cast(<<_::binary-size(4)>> = identifier) do
    {:ok, identifier}
  end

  def cast(_), do: :error

  @impl true
  @spec dump(t()) :: {:ok, integer} | :error
  def dump(<<num::integer-signed-32>>) do
    {:ok, num}
  end

  def dump(_), do: :error
end
