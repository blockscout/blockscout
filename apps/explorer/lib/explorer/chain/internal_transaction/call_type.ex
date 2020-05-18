defmodule Explorer.Chain.InternalTransaction.CallType do
  @moduledoc """
  Internal transaction types
  """

  use Ecto.Type

  @typedoc """
   * `:call` - call a function in a contract by jumping into the contract's context
   * `:callcode`
   * `:delegatecall` - Instead of jumping into the code as with `"call"`, and using the call's contract's context, use
     the current contract's context with the delegated contract's code.  There's some good chances for finding bugs
     when fuzzing these if the memory layout differs between the current contract and the delegated contract.
   * `:staticcall`
  """
  @type t :: :call | :callcode | :delegatecall | :staticcall

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
  def cast(t) when t in ~w(call callcode delegatecall staticcall)a, do: {:ok, t}
  def cast("call"), do: {:ok, :call}
  def cast("callcode"), do: {:ok, :callcode}
  def cast("delegatecall"), do: {:ok, :delegatecall}
  def cast("staticcall"), do: {:ok, :staticcall}
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
  def dump(:call), do: {:ok, "call"}
  def dump(:callcode), do: {:ok, "callcode"}
  def dump(:delegatecall), do: {:ok, "delegatecall"}
  def dump(:staticcall), do: {:ok, "staticcall"}
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
  def load("call"), do: {:ok, :call}
  def load("callcode"), do: {:ok, :callcode}
  def load("delegatecall"), do: {:ok, :delegatecall}
  def load("staticcall"), do: {:ok, :staticcall}
  def load(_), do: :error

  @doc """
  The underlying database type: `:string`
  """
  @impl Ecto.Type
  @spec type() :: :string
  def type, do: :string
end
