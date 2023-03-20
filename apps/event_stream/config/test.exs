import Config

config :event_stream, EventStream.Publisher, EventStream.Publisher.Mock

# don't trigger periodic flush in tests
config :event_stream, :buffer_flush_interval, :timer.hours(2)
