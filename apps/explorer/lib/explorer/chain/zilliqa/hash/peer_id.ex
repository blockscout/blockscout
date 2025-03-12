defmodule Explorer.Chain.Zilliqa.Hash.PeerID do
  @moduledoc """
  libp2p peer ID, corresponding to the staker's `blsPubKey`
  """

  alias Explorer.Chain.Hash

  use Ecto.Type
  @behaviour Hash

  @byte_count 38

  @typedoc """
  A #{@byte_count}-byte libp2p peer ID hash, corresponding to the staker's
  `blsPubKey`.
  """
  @type t :: %Hash{byte_count: unquote(@byte_count), bytes: <<_::unquote(@byte_count * Hash.bits_per_byte())>>}

  @doc """
  Casts a term to a `t`.
  """
  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(term) do
    Hash.cast(__MODULE__, term)
  end

  @doc """
  Dumps a `t` to a binary.
  """
  @impl Ecto.Type
  @spec dump(term()) :: {:ok, binary} | :error
  def dump(term) do
    Hash.dump(__MODULE__, term)
  end

  @doc """
  Loads a binary to a `t`.
  """
  @impl Ecto.Type
  @spec load(term()) :: {:ok, t()} | :error
  def load(term) do
    Hash.load(__MODULE__, term)
  end

  @doc """
  Returns the type of the `t`.
  """
  @impl Ecto.Type
  @spec type() :: :binary
  def type, do: :binary

  @doc """
  Returns the byte count of the `t`.
  """
  @impl Hash
  def byte_count, do: @byte_count
end
