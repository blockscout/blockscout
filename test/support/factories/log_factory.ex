defmodule Explorer.LogFactory do
  defmacro __using__(_opts) do
    quote do
      def log_factory do
        %Explorer.Log{
          index: sequence(""),
          data: sequence("0x"),
          removed: Enum.random([true, false]),
          first_topic: sequence("0x"),
          second_topic: sequence("0x"),
          third_topic: sequence("0x"),
        }
      end
    end
  end
end
