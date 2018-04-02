defmodule Explorer.ToAddressFactory do
  defmacro __using__(_opts) do
    quote do
      def to_address_factory do
        %Explorer.ToAddress{}
      end
    end
  end
end
