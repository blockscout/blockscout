defmodule Explorer.Chain.Transaction.Status do
  @moduledoc """
  Whether a transaction succeeded (`:ok`) or failed (`:error`).

  Post-[Byzantium](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-609.md) status is `0x1` for success and `0x0`
  for failure, but instead of keeping track of just an integer and having to remember if its like C boolean (`0` for
  `false`, `1` for `true`) or a Posix exit code, let's represent it as native elixir - `:ok` for success and `:error`
  for failure.
  """

  use Ecto.Type

  @typedoc """
   * `:ok` - transaction succeeded
   * `:error` - transaction failed
  """
  @type t :: :ok | :error

  @doc """
  Casts `term` to `t:t/0`

  If the `term` is already in `t:t/0`, then it is returned

      iex> Explorer.Chain.Transaction.Status.cast(:ok)
      {:ok, :ok}
      iex> Explorer.Chain.Transaction.Status.cast(:error)
      {:ok, :error}

  If the `term` is an `non_neg_integer`, then it is converted only if it is `0` or `1`.

      iex> Explorer.Chain.Transaction.Status.cast(0)
      {:ok, :error}
      iex> Explorer.Chain.Transaction.Status.cast(1)
      {:ok, :ok}
      iex> Explorer.Chain.Transaction.Status.cast(2)
      :error

  If the `term` is in the quantity format used by `Explorer.JSONRPC`, it is converted only if `0x0` or `0x1`

      iex> Explorer.Chain.Transaction.Status.cast("0x0")
      {:ok, :error}
      iex> Explorer.Chain.Transaction.Status.cast("0x1")
      {:ok, :ok}
      iex> Explorer.Chain.Transaction.Status.cast("0x2")
      :error

  """
  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(:error), do: {:ok, :error}
  def cast(:ok), do: {:ok, :ok}
  def cast(0), do: {:ok, :error}
  def cast(1), do: {:ok, :ok}
  def cast("0x0"), do: {:ok, :error}
  def cast("0x1"), do: {:ok, :ok}
  def cast(_), do: :error

  @doc """
  Dumps the `atom` format to `integer` format used in database.

      iex> Explorer.Chain.Transaction.Status.dump(:ok)
      {:ok, 1}
      iex> Explorer.Chain.Transaction.Status.dump(:error)
      {:ok, 0}

  If the value hasn't been cast first, it can't be dumped.

      iex> Explorer.Chain.Transaction.Status.dump(0)
      :error
      iex> Explorer.Chain.Transaction.Status.dump(1)
      :error
      iex> Explorer.Chain.Transaction.Status.dump("0x0")
      :error
      iex> Explorer.Chain.Transaction.Status.dump("0x1")
      :error

  """
  @impl Ecto.Type
  @spec dump(term()) :: {:ok, 0 | 1} | :error
  def dump(:error), do: {:ok, 0}
  def dump(:ok), do: {:ok, 1}
  def dump(_), do: :error

  @doc """
  Loads the integer from the database.

  Only loads integers `0` and `1`.

      iex> Explorer.Chain.Transaction.Status.load(0)
      {:ok, :error}
      iex> Explorer.Chain.Transaction.Status.load(1)
      {:ok, :ok}
      iex> Explorer.Chain.Transaction.Status.load(2)
      :error

  """
  @impl Ecto.Type
  @spec load(term()) :: {:ok, t()} | :error
  def load(0), do: {:ok, :error}
  def load(1), do: {:ok, :ok}
  def load(_), do: :error

  @doc """
  The underlying database type: `:integer`
  """
  @impl Ecto.Type
  @spec type() :: :integer
  def type, do: :integer
end
