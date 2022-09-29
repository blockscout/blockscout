defmodule Explorer.Encrypted.Types.AddressHash do
  @moduledoc """
    An `Ecto.Type` to encrypt address_hash fields.
  """

  @doc false
  defmacro __using__(opts) do
    opts = Keyword.merge(opts, vault: Keyword.fetch!(opts, :vault))

    quote do
      use Cloak.Ecto.Type, unquote(opts)

      def cast(value) do
        Explorer.Chain.Hash.Address.cast(value)
      end

      def after_decrypt(nil), do: nil
      def after_decrypt(""), do: nil
      def after_decrypt(:error), do: nil

      def after_decrypt(value) do
        {:ok, address_hash} = Explorer.Chain.Hash.Address.cast(value)
        address_hash
      end
    end
  end
end
