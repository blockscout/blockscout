defmodule Explorer.Chain.FromAddressFactory do
  defmacro __using__(_opts) do
    quote do
      def from_address_factory do
        %Explorer.Chain.FromAddress{}
      end
    end
  end
end
