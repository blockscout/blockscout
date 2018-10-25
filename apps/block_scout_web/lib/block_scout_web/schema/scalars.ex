defmodule BlockScoutWeb.Schema.Scalars do
  @moduledoc false

  use Absinthe.Schema.Notation

  alias Explorer.Chain.Hash
  alias Explorer.Chain.Hash.{Address, Full, Nonce}

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
end
