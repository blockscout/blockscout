defmodule Explorer.Chain.InternalTransaction.Type do
  @moduledoc """
  Internal transaction types
  """

  use Ecto.Type
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  @typedoc """
   * `:call`
   * `:create`
   * `:create2`
   * `:reward`
   * `:selfdestruct`
   * `:stop`
   #{if @chain_type == :arbitrum do
    """
      * `:invalid`
    """
  else
    ""
  end}
  """
  if @chain_type == :arbitrum do
    @type_values ["call", "create", "create2", "reward", "selfdestruct", "stop", "invalid"]
    @type t :: :call | :create | :create2 | :reward | :selfdestruct | :stop | :invalid
  else
    @type_values ["call", "create", "create2", "reward", "selfdestruct", "stop"]
    @type t :: :call | :create | :create2 | :reward | :selfdestruct | :stop
  end

  @doc """
  Casts `term` to `t:t/0`

  If the `term` is already in `t:t/0`, then it is returned

      iex> Explorer.Chain.InternalTransaction.Type.cast(:call)
      {:ok, :call}
      iex> Explorer.Chain.InternalTransaction.Type.cast(:create)
      {:ok, :create}
      iex> Explorer.Chain.InternalTransaction.Type.cast(:create2)
      {:ok, :create2}
      iex> Explorer.Chain.InternalTransaction.Type.cast(:reward)
      {:ok, :reward}
      iex> Explorer.Chain.InternalTransaction.Type.cast(:selfdestruct)
      {:ok, :selfdestruct}

  If `term` is a `String.t`, then it is converted to the corresponding `t:t/0`.

      iex> Explorer.Chain.InternalTransaction.Type.cast("call")
      {:ok, :call}
      iex> Explorer.Chain.InternalTransaction.Type.cast("create")
      {:ok, :create}
      iex> Explorer.Chain.InternalTransaction.Type.cast("create2")
      {:ok, :create2}
      iex> Explorer.Chain.InternalTransaction.Type.cast("reward")
      {:ok, :reward}
      iex> Explorer.Chain.InternalTransaction.Type.cast("selfdestruct")
      {:ok, :selfdestruct}

  Deprecated values are not allowed for incoming data.

      iex> Explorer.Chain.InternalTransaction.Type.cast(:suicide)
      :error
      iex> Explorer.Chain.InternalTransaction.Type.cast("suicide")
      :error

  Unsupported `String.t` return an `:error`.

      iex> Explorer.Chain.InternalTransaction.Type.cast("hard-fork")
      :error

  """
  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(type) when type in ~w(call create create2 selfdestruct reward)a, do: {:ok, type}

  def cast(type) when type in ["call", "create", "create2", "reward", "selfdestruct", "stop"],
    do: {:ok, String.to_existing_atom(type)}

  if @chain_type == :arbitrum do
    def cast("invalid"), do: {:ok, :invalid}
  end

  def cast(_), do: :error

  @doc """
  Dumps the `atom` format to `String.t` format used in the database.

      iex> Explorer.Chain.InternalTransaction.Type.dump(:call)
      {:ok, "call"}
      iex> Explorer.Chain.InternalTransaction.Type.dump(:create)
      {:ok, "create"}
      iex> Explorer.Chain.InternalTransaction.Type.dump(:create2)
      {:ok, "create2"}
      iex> Explorer.Chain.InternalTransaction.Type.dump(:reward)
      {:ok, "reward"}
      iex> Explorer.Chain.InternalTransaction.Type.dump(:selfdestruct)
      {:ok, "selfdestruct"}

  Deprecated values are not allowed to be dumped to the database as old values should only be read, not written.

      iex> Explorer.Chain.InternalTransaction.Type.dump(:suicide)
      :error

  Other atoms return an error

      iex> Explorer.Chain.InternalTransaction.Type.dump(:other)
      :error

  """
  @impl Ecto.Type
  @spec dump(term()) :: {:ok, String.t()} | :error
  def dump(type) when type in [:call, :create, :create2, :reward, :selfdestruct, :stop], do: {:ok, Atom.to_string(type)}

  if @chain_type == :arbitrum do
    def dump(:invalid), do: {:ok, "invalid"}
  end

  def dump(_), do: :error

  @doc """
  Loads the `t:String.t/0` from the database.

      iex> Explorer.Chain.InternalTransaction.Type.load("call")
      {:ok, :call}
      iex> Explorer.Chain.InternalTransaction.Type.load("create")
      {:ok, :create}
      iex> Explorer.Chain.InternalTransaction.Type.load("create2")
      {:ok, :create2}
      iex> Explorer.Chain.InternalTransaction.Type.load("reward")
      {:ok, :reward}
      iex> Explorer.Chain.InternalTransaction.Type.load("selfdestruct")
      {:ok, :selfdestruct}

  Converts deprecated value on load to the corresponding `t:t/0`.

      iex> Explorer.Chain.InternalTransaction.Type.load("suicide")
      {:ok, :selfdestruct}

  Other `t:String.t/0` return `:error`

      iex> Explorer.Chain.InternalTransaction.Type.load("other")
      :error

  """
  @impl Ecto.Type
  @spec load(term()) :: {:ok, t()} | :error
  def load(type) when type in ["call", "create", "create2", "reward", "selfdestruct", "stop"],
    do: {:ok, String.to_existing_atom(type)}

  if @chain_type == :arbitrum do
    def load("invalid"), do: {:ok, :invalid}
  end

  # deprecated
  def load("suicide"), do: {:ok, :selfdestruct}
  def load(_), do: :error

  @doc """
  The underlying database type: `:string`
  """
  @impl Ecto.Type
  @spec type() :: :string
  def type, do: :string

  @doc """
  Returns the list of internal transaction type values.

  ## Example

    > Explorer.Chain.InternalTransaction.Type.values()
    ["call", "create", "create2", "reward", "selfdestruct", "stop"]
  """
  @spec values :: [String.t()]
  def values, do: @type_values
end
