defmodule Explorer.Utility.VersionConstantsUpdater do
  @moduledoc """
  Module responsible for updating current and previous backend version in table `constants`.
  """

  use GenServer

  alias Explorer.Application.Constants

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    set_versions()
    :ignore
  end

  defp set_versions do
    stored_current_version = Constants.get_current_backend_version()
    current_version = to_string(Application.spec(:explorer, :vsn))

    if not is_nil(stored_current_version) and stored_current_version != current_version do
      Constants.insert_previous_backend_version(stored_current_version)
    end

    if stored_current_version != current_version do
      Constants.insert_current_backend_version(current_version)
    end
  end
end
