defmodule Explorer.Chain.LogFactory do
  defmacro __using__(_opts) do
    quote do
      def log_factory do
        %Explorer.Chain.Log{
          address_id: insert(:address).id,
          data: sequence("0x"),
          first_topic: nil,
          fourth_topic: nil,
          index: sequence(""),
          second_topic: nil,
          third_topic: nil,
          type: sequence("0x")
        }
      end
    end
  end
end
