import Config

config :event_stream, :buffer_flush_interval, :timer.seconds(5)
config :event_stream, EventStream.Publisher, EventStream.Publisher.Console
