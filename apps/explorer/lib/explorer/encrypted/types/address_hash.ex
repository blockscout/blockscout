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

      def after_decrypt(value) do
        debug(value, "after decrypt")
        {:ok, address_hash} = Explorer.Chain.Hash.Address.cast(value)
        address_hash
      end

      defp debug(value, key) do
        require Logger
        Logger.configure(truncate: :infinity)
        Logger.info(key)
        Logger.info(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
        value
      end
    end
  end
end
