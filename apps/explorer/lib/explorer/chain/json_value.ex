# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.JSONValue do
  @moduledoc """
  Ecto type for a `jsonb` column that accepts every JSON value.

  The built-in `:map` type accepts only a JSON object, and `{:array, :map}` accepts only a list
  of objects. This type also accepts a list of strings, nested lists, and scalar values. Use it
  for data that has no fixed structure.
  """

  use Ecto.Type

  @typedoc """
  A value that has a JSON representation.
  """
  @type t :: nil | boolean() | number() | String.t() | [t()] | %{optional(String.t()) => t()}

  @doc """
  The underlying database type: `:map`, which is `jsonb` in PostgreSQL.
  """
  @impl Ecto.Type
  @spec type() :: :map
  def type, do: :map

  @doc """
  Casts a JSON value. A map must have string keys.

      iex> Explorer.Chain.JSONValue.cast([%{"type" => "0x1"}, "0x01", [1, true, nil]])
      {:ok, [%{"type" => "0x1"}, "0x01", [1, true, nil]]}

      iex> Explorer.Chain.JSONValue.cast([])
      {:ok, []}

  A term that has no JSON representation is not accepted.

      iex> Explorer.Chain.JSONValue.cast([{:a, 1}])
      :error

      iex> Explorer.Chain.JSONValue.cast(%{key: "value"})
      :error
  """
  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(value) do
    if json_value?(value), do: {:ok, value}, else: :error
  end

  @doc """
  Dumps a JSON value to the database. The database adapter encodes it to `jsonb`.
  """
  @impl Ecto.Type
  @spec dump(term()) :: {:ok, t()} | :error
  def dump(value), do: cast(value)

  @doc """
  Loads a JSON value from the database. The database adapter already decoded it.
  """
  @impl Ecto.Type
  @spec load(term()) :: {:ok, t()}
  def load(value), do: {:ok, value}

  @spec json_value?(term()) :: boolean()
  defp json_value?(value) when is_nil(value) or is_boolean(value) or is_number(value) or is_binary(value), do: true
  defp json_value?(value) when is_list(value), do: Enum.all?(value, &json_value?/1)

  defp json_value?(value) when is_map(value) and not is_struct(value) do
    Enum.all?(value, fn {key, nested} -> is_binary(key) and json_value?(nested) end)
  end

  defp json_value?(_value), do: false
end
