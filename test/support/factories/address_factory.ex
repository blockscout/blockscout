defmodule Explorer.AddressFactory do
  defmacro __using__(_opts) do
    quote do
      def address_factory do
        %Explorer.Address{
          hash: String.pad_trailing(sequence("0x"), 42, "address")
        }
      end
    end
  end
end
