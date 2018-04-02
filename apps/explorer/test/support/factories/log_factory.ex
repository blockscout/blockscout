defmodule Explorer.LogFactory do
  defmacro __using__(_opts) do
    quote do
      def log_factory do
        %Explorer.Log{
          index: sequence(""),
          data: sequence("0x"),
          type: sequence("0x"),
          first_topic: nil,
          second_topic: nil,
          third_topic: nil,
          fourth_topic: nil
        }
      end
    end
  end
end
