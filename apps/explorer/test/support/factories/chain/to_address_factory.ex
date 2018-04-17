defmodule Explorer.Chain.ToAddressFactory do
  defmacro __using__(_opts) do
    quote do
      def to_address_factory do
        %Explorer.Chain.ToAddress{}
      end
    end
  end
end
