defmodule Explorer.Celo.Telemetry.Instrumentation.Api do
  @moduledoc "Api metric definitions"

  alias Explorer.Celo.Telemetry.Instrumentation
  use Instrumentation

  def metrics do
    [
      distribution("api_graphql_operation_duration_milliseconds",
        reporter_options: [
          buckets: [
            50,
            100,
            300,
            500,
            :timer.seconds(1),
            :timer.seconds(3),
            :timer.seconds(5),
            :timer.seconds(10),
            :timer.seconds(30),
            :timer.minutes(1)
          ]
        ],
        event_name: [:absinthe, :execute, :operation, :stop],
        measurement: :duration,
        description: "Operation times for requests send to Blockscout API",
        tags: [:label],
        tag_values: fn metadata ->
          if Keyword.has_key?(metadata.options, :document) and is_binary(metadata.options[:document]) do
            document_hash = Base.encode16(:crypto.hash(:sha256, metadata.options[:document]), case: :lower)

            %{
              label:
                case document_hash do
                  "d545db1eaf240b6ebefe95eb095db8bf572eddd382b3b4b695b6eb31dbcdabe1" -> "transfers"
                  _ -> "unlabelled"
                end
            }
          else
            %{}
          end
        end,
        unit: {:native, :millisecond}
      )
    ]
  end
end
