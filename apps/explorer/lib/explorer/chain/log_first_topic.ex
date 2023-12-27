defmodule Explorer.Chain.LogFirstTopic do
  @moduledoc "Storage of event log's first topic"

  use Explorer.Schema

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Hash
  alias Explorer.Repo

  @required_attrs ~w(first_topic)a

  @typedoc """
  * `:id` - id of First topic
  * `first_topic` - `topics[0]`
  """
  @type t :: %__MODULE__{
          hash: Hash.Full.t()
        }

  @primary_key false
  schema "log_first_topics" do
    field(:id, :integer)
    field(:hash, Hash.Full)

    timestamps()
  end

  @doc false
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_attrs)
    |> validate_required(@required_attrs)
  end

  def get_log_first_topic_ids_by_hashes(topic_hashes) do
    query =
      from(log_first_topic in __MODULE__,
        select: {log_first_topic.id, log_first_topic.hash},
        where: log_first_topic.hash in ^topic_hashes
      )

    query
    |> Repo.all(timeout: :infinity)
  end
end
