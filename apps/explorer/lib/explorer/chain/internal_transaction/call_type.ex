defmodule Explorer.Chain.InternalTransaction.CallType do
  @moduledoc """
  Internal transaction types
  """

  use Ecto.Type
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  @base_call_types ~w(call callcode delegatecall staticcall)a
  if @chain_type == :arbitrum do
    @call_types @base_call_types ++ ~w(invalid)a
  else
    @call_types @base_call_types
  end

  @typedoc """
   * `:call` - call a function in a contract by jumping into the contract's context
   * `:callcode`
   * `:delegatecall` - Instead of jumping into the code as with `"call"`, and using the call's contract's context, use
     the current contract's context with the delegated contract's code.  There's some good chances for finding bugs
     when fuzzing these if the memory layout differs between the current contract and the delegated contract.
   * `:staticcall`
   #{if @chain_type == :arbitrum do
    """
      * `:invalid`
    """
  else
    ""
  end}
  """
  if @chain_type == :arbitrum do
    @type t :: :call | :callcode | :delegatecall | :staticcall | :invalid
  else
    @type t :: :call | :callcode | :delegatecall | :staticcall
  end

  @doc """
  Casts `term` to `t:t/0`

  If the `term` is already in `t:t/0`, then it is returned

      iex> Explorer.Chain.InternalTransaction.CallType.cast(:call)
      {:ok, :call}
      iex> Explorer.Chain.InternalTransaction.CallType.cast(:callcode)
      {:ok, :callcode}
      iex> Explorer.Chain.InternalTransaction.CallType.cast(:delegatecall)
      {:ok, :delegatecall}
      iex> Explorer.Chain.InternalTransaction.CallType.cast(:staticcall)
      {:ok, :staticcall}

  If `term` is a `String.t`, then it is converted to the corresponding `t:t/0`.

      iex> Explorer.Chain.InternalTransaction.CallType.cast("call")
      {:ok, :call}
      iex> Explorer.Chain.InternalTransaction.CallType.cast("callcode")
      {:ok, :callcode}
      iex> Explorer.Chain.InternalTransaction.CallType.cast("delegatecall")
      {:ok, :delegatecall}
      iex> Explorer.Chain.InternalTransaction.CallType.cast("staticcall")
      {:ok, :staticcall}

  Unsupported `String.t` return an `:error`.

      iex> Explorer.Chain.InternalTransaction.CallType.cast("hard-fork")
      :error

  """
  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(type) when type in @call_types, do: {:ok, type}

  def cast(call_type) when call_type in ["call", "callcode", "delegatecall", "staticcall"],
    do: {:ok, String.to_existing_atom(call_type)}

  if @chain_type == :arbitrum do
    def cast("invalid"), do: {:ok, :invalid}
  end

  def cast(_), do: :error

  @doc """
  Dumps the `atom` format to `String.t` format used in the database.

      iex> Explorer.Chain.InternalTransaction.CallType.dump(:call)
      {:ok, "call"}
      iex> Explorer.Chain.InternalTransaction.CallType.dump(:callcode)
      {:ok, "callcode"}
      iex> Explorer.Chain.InternalTransaction.CallType.dump(:delegatecall)
      {:ok, "delegatecall"}
      iex> Explorer.Chain.InternalTransaction.CallType.dump(:staticcall)
      {:ok, "staticcall"}

  Other atoms return an error

      iex> Explorer.Chain.InternalTransaction.CallType.dump(:other)
      :error

  """
  @impl Ecto.Type
  @spec dump(term()) :: {:ok, String.t()} | :error
  def dump(call_type) when call_type in @call_types, do: {:ok, Atom.to_string(call_type)}
  def dump(_), do: :error

  @doc """
  Loads the `t:String.t/0` from the database.

      iex> Explorer.Chain.InternalTransaction.CallType.load("call")
      {:ok, :call}
      iex> Explorer.Chain.InternalTransaction.CallType.load("callcode")
      {:ok, :callcode}
      iex> Explorer.Chain.InternalTransaction.CallType.load("delegatecall")
      {:ok, :delegatecall}
      iex> Explorer.Chain.InternalTransaction.CallType.load("staticcall")
      {:ok, :staticcall}

  Other `t:String.t/0` return `:error`

      iex> Explorer.Chain.InternalTransaction.CallType.load("other")
      :error

  """
  @impl Ecto.Type
  @spec load(term()) :: {:ok, t()} | :error
  def load(call_type) when call_type in ["call", "callcode", "delegatecall", "staticcall"],
    do: {:ok, String.to_existing_atom(call_type)}

  if @chain_type == :arbitrum do
    def load("invalid"), do: {:ok, :invalid}
  end

  def load(_), do: :error

  @doc """
  The underlying database type: `:string`
  """
  @impl Ecto.Type
  @spec type() :: :string
  def type, do: :string

  @doc """
  Returns the list of `t:t/0` values as `String.t` list

  ## Examples

    > Explorer.Chain.InternalTransaction.CallType.values()
    ["call", "callcode", "delegatecall", "staticcall"]
  """
  @spec values :: [String.t()]
  def values, do: @call_types |> Enum.map(&to_string/1)
end
