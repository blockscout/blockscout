import Config

config :event_stream, :buffer_flush_interval, :timer.seconds(5)

if System.get_env("ENABLE_BEANSTALKD") != nil do
  config :event_stream, EventStream.Publisher, EventStream.Publisher.Beanstalkd

  config :event_stream, :beanstalkd,
    enabled: true,
    host: System.get_env("BEANSTALKD_HOST"),
    port: System.get_env("BEANSTALKD_PORT", "11300") |> String.to_integer(),
    tube: System.get_env("BEANSTALKD_TUBE", "default")
else
  config :event_stream, EventStream.Publisher, EventStream.Publisher.Console
  config :event_stream, :beanstalkd, enabled: false
end

import_config "#{config_env()}.exs"
