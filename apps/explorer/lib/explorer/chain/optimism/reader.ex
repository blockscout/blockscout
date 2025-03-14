defmodule Explorer.Chain.Optimism.Reader do
  @moduledoc "Contains read functions for Optimism modules."
  import Ecto.Query,
    only: [from: 2]

  import Explorer.Chain, only: [select_repo: 1]
  alias Explorer.Chain.Optimism.FrameSequence

  @doc """
    Gets information about the latest batch and calculates average time between batches, in seconds.

    ## Parameters
      - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - If at least two batches exist:
      `{:ok, %{latest_batch_number: integer, latest_batch_timestamp: DateTime.t(), average_batch_time: integer}}`
      where:
        * latest_batch_number - id of the latest batch in the database.
        * latest_batch_timestamp - when the latest batch was committed to L1.
        * average_batch_time - average number of seconds between batches for the last 100 batches.

    - If less than two batches exist: `{:error, :not_found}`.
  """
  @spec get_latest_batch_info(keyword()) :: {:ok, map()} | {:error, :not_found}
  def get_latest_batch_info(options \\ []) do
    query =
      from(fs in FrameSequence,
        where: fs.view_ready == true,
        order_by: [desc: fs.id],
        limit: 5,
        select: %{
          id: fs.id,
          timestamp: fs.l1_timestamp
        }
      )

    items = select_repo(options).all(query)
    items_count = length(items)

    if items_count > 1 do
      latest_item = List.first(items)
      older_item = List.last(items)
      average_time = div(DateTime.diff(latest_item.timestamp, older_item.timestamp, :second), items_count)

      {
        :ok,
        %{
          latest_batch_number: latest_item.id,
          latest_batch_timestamp: latest_item.timestamp,
          average_batch_time: average_time
        }
      }
    else
      {:error, :not_found}
    end
  end
end
