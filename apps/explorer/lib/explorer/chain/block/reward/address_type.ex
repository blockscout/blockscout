defmodule Explorer.Chain.Block.Reward.AddressType do
  @moduledoc """
  Block reward address types
  """

  use Ecto.Type

  @typedoc """
   * `:emission_funds`
   * `:uncle`
   * `:validator`
  """
  @type t :: :emission_funds | :uncle | :validator

  @doc """
  Casts `term` to `t:t/0`

  If the `term` is already in `t:t/0`, then it is returned

      iex> Explorer.Chain.Block.Reward.AddressType.cast(:emission_funds)
      {:ok, :emission_funds}
      iex> Explorer.Chain.Block.Reward.AddressType.cast(:uncle)
      {:ok, :uncle}
      iex> Explorer.Chain.Block.Reward.AddressType.cast(:validator)
      {:ok, :validator}

  If `term` is a `String.t`, then it is converted to the corresponding `t:t/0`.

      iex> Explorer.Chain.Block.Reward.AddressType.cast("emission_funds")
      {:ok, :emission_funds}
      iex> Explorer.Chain.Block.Reward.AddressType.cast("uncle")
      {:ok, :uncle}
      iex> Explorer.Chain.Block.Reward.AddressType.cast("validator")
      {:ok, :validator}

  Unsupported `String.t` return an `:error`.

      iex> Explorer.Chain.Block.Reward.AddressType.cast("hard-fork")
      :error

  """
  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(t) when t in ~w(emission_funds uncle validator)a, do: {:ok, t}
  def cast("emission_funds"), do: {:ok, :emission_funds}
  def cast("uncle"), do: {:ok, :uncle}
  def cast("validator"), do: {:ok, :validator}
  def cast(_), do: :error

  @doc """
  Dumps the `atom` format to `String.t` format used in the database.

      iex> Explorer.Chain.Block.Reward.AddressType.dump(:emission_funds)
      {:ok, "emission_funds"}
      iex> Explorer.Chain.Block.Reward.AddressType.dump(:uncle)
      {:ok, "uncle"}
      iex> Explorer.Chain.Block.Reward.AddressType.dump(:validator)
      {:ok, "validator"}


  Other atoms return an error

      iex> Explorer.Chain.Block.Reward.AddressType.dump(:other)
      :error

  """
  @impl Ecto.Type
  @spec dump(term()) :: {:ok, String.t()} | :error
  def dump(:emission_funds), do: {:ok, "emission_funds"}
  def dump(:uncle), do: {:ok, "uncle"}
  def dump(:validator), do: {:ok, "validator"}
  def dump(_), do: :error

  @doc """
  Loads the `t:String.t/0` from the database.

      iex> Explorer.Chain.Block.Reward.AddressType.load("emission_funds")
      {:ok, :emission_funds}
      iex> Explorer.Chain.Block.Reward.AddressType.load("uncle")
      {:ok, :uncle}
      iex> Explorer.Chain.Block.Reward.AddressType.load("validator")
      {:ok, :validator}

  Other `t:String.t/0` return `:error`

      iex> Explorer.Chain.Block.Reward.AddressType.load("other")
      :error

  """
  @impl Ecto.Type
  @spec load(term()) :: {:ok, t()} | :error
  def load("emission_funds"), do: {:ok, :emission_funds}
  def load("uncle"), do: {:ok, :uncle}
  def load("validator"), do: {:ok, :validator}
  def load(_), do: :error

  @doc """
  The underlying database type: `:string`
  """
  @impl Ecto.Type
  @spec type() :: :string
  def type, do: :string
end
