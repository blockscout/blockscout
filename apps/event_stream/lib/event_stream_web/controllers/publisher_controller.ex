defmodule EventStream.PublisherController do
  use EventStream, :controller

  alias EventStream.Publisher.Beanstalkd

  def stats(conn, _params) do
    render(conn, "stats.html", get_stats())
  end

  defp get_stats do
    publisher = Application.get_env(:event_stream, EventStream.Publisher)

    %{
      publisher: publisher,
      stats: get_stats(publisher)
    }
  end

  defp get_stats(EventStream.Publisher.Beanstalkd), do: Beanstalkd.stats()
  defp get_stats(_some_other_publisher), do: %{}
end
