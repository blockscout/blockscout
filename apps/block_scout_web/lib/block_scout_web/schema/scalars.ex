defmodule BlockScoutWeb.Schema.Scalars do
  @moduledoc false

  use Absinthe.Schema.Notation

  alias Explorer.Chain.{Data, Hash, Wei}
  alias Explorer.Chain.Hash.{Address, Full, Nonce}

  import_types(BlockScoutWeb.Schema.Scalars.JSON)

  @desc """
  The address (40 (hex) characters / 160 bits / 20 bytes) is derived from the public key (128 (hex) characters /
  512 bits / 64 bytes) which is derived from the private key (64 (hex) characters / 256 bits / 32 bytes).

  The address is actually the last 40 characters of the keccak-256 hash of the public key with `0x` appended.
  """
  scalar :address_hash do
    parse(fn
      %Absinthe.Blueprint.Input.String{value: value} ->
        Hash.cast(Address, value)

      _ ->
        :error
    end)

    serialize(&to_string/1)
  end

  @desc """
  An unpadded hexadecimal number with 0 or more digits. Each pair of digits
  maps directly to a byte in the underlying binary representation. When
  interpreted as a number, it should be treated as big-endian.
  """
  scalar :data do
    parse(fn
      %Absinthe.Blueprint.Input.String{value: value} ->
        Data.cast(value)

      _ ->
        :error
    end)

    serialize(&to_string/1)
  end

  @desc """
  A 32-byte [KECCAK-256](https://en.wikipedia.org/wiki/SHA-3) hash.
  """
  scalar :full_hash do
    parse(fn
      %Absinthe.Blueprint.Input.String{value: value} ->
        Hash.cast(Full, value)

      _ ->
        :error
    end)

    serialize(&to_string/1)
  end

  @desc """
  The nonce (16 (hex) characters / 128 bits / 8 bytes) is derived from the Proof-of-Work.
  """
  scalar :nonce_hash do
    parse(fn
      %Absinthe.Blueprint.Input.String{value: value} ->
        Hash.cast(Nonce, value)

      _ ->
        :error
    end)

    serialize(&to_string/1)
  end

  @desc """
  The smallest fractional unit of Ether. Using wei instead of ether allows code to do integer match instead of using
  floats.

  See [Ethereum Homestead Documentation](http://ethdocs.org/en/latest/ether.html) for examples of various denominations of wei.

  Etymology of "wei" comes from [Wei Dai (戴維)](https://en.wikipedia.org/wiki/Wei_Dai), a
  [cypherpunk](https://en.wikipedia.org/wiki/Cypherpunk) who came up with b-money, which outlined modern
  cryptocurrencies.
  """
  scalar :wei do
    parse(fn
      %Absinthe.Blueprint.Input.String{value: value} ->
        Wei.cast(value)

      _ ->
        :error
    end)

    serialize(&to_string(&1.value))
  end

  enum :status do
    value(:ok)
    value(:error)
  end

  enum :call_type do
    value(:call)
    value(:callcode)
    value(:delegatecall)
    value(:staticcall)
  end

  enum :type do
    value(:call)
    value(:create)
    value(:reward)
    value(:selfdestruct)
  end

  enum :sort_order do
    value(:asc)
    value(:desc)
  end
end
