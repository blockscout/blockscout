defmodule Explorer.Admin.Administrator.Role do
  @moduledoc """
  Supported roles for an administrator.
  """

  use Ecto.Type

  @typedoc """
  Supported role atoms for an administrator.
  """
  @type t :: :owner

  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(t) when t in ~w(owner)a, do: {:ok, t}
  def cast("owner"), do: {:ok, :owner}
  def cast(_), do: :error

  @impl Ecto.Type
  @spec dump(term()) :: {:ok, String.t()} | :error
  def dump(:owner), do: {:ok, "owner"}
  def dump(_), do: :error

  @impl Ecto.Type
  @spec load(term) :: {:ok, t()} | :error
  def load("owner"), do: {:ok, :owner}
  def load(_), do: :error

  @impl Ecto.Type
  @spec type() :: :string
  def type, do: :string
end
