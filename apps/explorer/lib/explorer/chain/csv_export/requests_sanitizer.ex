defmodule Explorer.Chain.CsvExport.RequestsSanitizer do
  @moduledoc """
  Oban cron worker that periodically deletes expired CSV export requests.

  Removes completed requests (file_id IS NOT NULL) whose updated_at
  is older than the configured Gokapi upload expiry period.
  """
  use Oban.Worker, queue: :csv_export_sanitize, max_attempts: 3

  import Ecto.Query

  alias Explorer.Chain.CsvExport.Request
  alias Explorer.Repo

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    expiry_days = csv_export_config()[:gokapi_upload_expiry_days]

    {count, _} =
      Request
      |> where([r], not is_nil(r.file_id))
      |> where([r], r.updated_at < ago(^expiry_days, "day"))
      |> Repo.delete_all()

    Logger.info("Deleted #{count} expired CSV export requests")

    :ok
  end

  defp csv_export_config, do: Application.get_env(:explorer, Explorer.Chain.CsvExport)
end
