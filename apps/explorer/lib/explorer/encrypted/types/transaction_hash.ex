defmodule Explorer.Encrypted.Types.TransactionHash do
  @moduledoc """
    An `Ecto.Type` to encrypt transaction_hash fields.
  """

  @doc false
  defmacro __using__(opts) do
    opts = Keyword.merge(opts, vault: Keyword.fetch!(opts, :vault))

    quote do
      use Cloak.Ecto.Type, unquote(opts)

      def cast(value) do
        Explorer.Chain.Hash.Full.cast(value)
      end

      def after_decrypt(nil), do: nil
      def after_decrypt(""), do: nil

      def after_decrypt(value) do
        {:ok, transaction_hash} = Explorer.Chain.Hash.Full.cast(value)
        transaction_hash
      end
    end
  end
end
