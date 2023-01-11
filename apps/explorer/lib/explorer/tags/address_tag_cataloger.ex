defmodule Explorer.Tags.AddressTag.Cataloger do
  @moduledoc """
  Actualizes address tags.
  """

  use GenServer

  alias Explorer.EnvVarTranslator
  alias Explorer.Repo
  alias Explorer.Tags.{AddressTag, AddressToTag}
  require Explorer.Celo.Telemetry, as: Telemetry

  @refresh_interval :timer.hours(1)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    send(self(), :fetch_tags)

    Process.send_after(self(), :update_validators_tags_bindings, @refresh_interval)

    {:ok, %{refresh_interval: @refresh_interval}}
  end

  @impl GenServer
  def handle_info(:fetch_tags, state) do
    create_new_tags()

    send(self(), :bind_addresses)

    {:noreply, state}
  end

  def handle_info(:bind_addresses, state) do
    all_tags = AddressTag.get_all_tags()

    all_tags
    |> Enum.each(fn %{label: tag_name} ->
      env_var_name = "CUSTOM_CONTRACT_ADDRESSES_#{tag_name_to_env_var_part(tag_name)}"
      set_tag_for_env_var_multiple_addresses(env_var_name, tag_name)
    end)

    {:noreply, state}
  end

  def handle_info(:update_validators_tags_bindings, %{refresh_interval: refresh_interval} = state) do
    Telemetry.wrap(:update_validators_tags_bindings, update_validators_tags_bindings())

    Process.send_after(self(), :update_validators_tags_bindings, refresh_interval)

    {:noreply, state}
  end

  defp update_validators_tags_bindings() do
    IO.inspect("Updating validators stuff")
    Repo.query!("CALL update_validators_tags_bindings();", [], timeout: :timer.seconds(30))
  end

  defp tag_name_to_env_var_part(tag_name) do
    tag_name
    |> String.upcase()
    |> String.replace(" ", "_")
    |> String.replace(".", "_")
  end

  def create_new_tags do
    tags = EnvVarTranslator.map_array_env_var_to_list(:new_tags)

    tags
    |> Enum.each(fn %{tag: tag_name, title: tag_display_name} ->
      AddressTag.set_tag(tag_name, tag_display_name)
    end)
  end

  defp set_tag_for_env_var_multiple_addresses(env_var, tag) do
    addresses = env_var_string_array_to_list(env_var)

    tag_id = AddressTag.get_tag_id(tag)
    AddressToTag.set_tag_to_addresses(tag_id, addresses)
  end

  defp env_var_string_array_to_list(env_var_array_string) do
    env_var =
      env_var_array_string
      |> System.get_env(nil)

    if env_var do
      env_var
      |> String.split(",")
      |> Enum.map(fn env_var_array_string_item ->
        env_var_array_string_item
        |> String.downcase()
      end)
    else
      []
    end
  end
end
