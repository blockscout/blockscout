defmodule Explorer.AddressFactory do
  defmacro __using__(_opts) do
    quote do
      def address_factory do
        %Explorer.Address{
          hash: sequence("0x"),
        }
      end
    end
  end
end
