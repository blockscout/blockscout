defmodule Explorer.Chain.CsvExport.Worker do
  @moduledoc """
  Oban worker for asynchronous CSV export jobs.

  Processes export requests in the background when the requested period exceeds
  the async threshold, streaming results to a temp file and uploading to storage.
  """
  use Oban.Worker, queue: :csv_export, max_attempts: 3

  alias Explorer.Chain.CsvExport.{AsyncHelper, Request}

  require Logger

  @impl Oban.Worker
  def perform(%Job{
        args:
          %{
            "request_id" => request_id,
            "address_hash" => address_hash,
            "from_period" => from_period,
            "to_period" => to_period,
            "show_scam_tokens?" => show_scam_tokens?,
            "module" => module
          } = args
      }) do
    csv_export_module = String.to_existing_atom(module)
    filename = "#{address_hash}_#{from_period}_#{to_period}.csv"

    result =
      address_hash
      |> csv_export_module.export(
        from_period,
        to_period,
        [show_scam_tokens?: show_scam_tokens?],
        args["filter_type"],
        args["filter_value"]
      )
      |> AsyncHelper.stream_to_temp_file(request_id)
      |> AsyncHelper.upload_file(filename, request_id)

    case result do
      {:ok, file_id} ->
        case Request.update_file_id(request_id, file_id) do
          {0, _} ->
            Logger.warning(
              "CSV export request #{request_id} was deleted before file_id could be set. Uploaded file #{file_id} may be orphaned."
            )

          {_count, _} ->
            :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
