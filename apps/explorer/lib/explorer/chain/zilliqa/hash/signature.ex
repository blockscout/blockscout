defmodule Explorer.Chain.Zilliqa.Hash.Signature do
  @moduledoc """
  A 96-byte BLS signature of the supermajority of the validators.
  """

  alias Explorer.Chain.Hash

  use Ecto.Type
  @behaviour Hash

  @byte_count 96

  @typedoc """
  A #{@byte_count}-byte BLS signature hash of the
  `t:Explorer.Chain.Zilliqa.QuorumCertificate.t/0` or
  `t:Explorer.Chain.Zilliqa.AggregateQuorumCertificate.t/0` or
  `t:Explorer.Chain.Zilliqa.NestedQuorumCertificate.t/0`.
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
