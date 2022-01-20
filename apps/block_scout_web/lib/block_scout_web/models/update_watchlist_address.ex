defmodule UpdateWatchlistAddress do
  @moduledoc """
  Update watchlist address, associated with Address and Watchlist
  """

  alias Ecto.Changeset
  alias Explorer.Repo

  def call(watchlist_address, params) do
    attrs = params_to_attributes(params)

    watchlist_address
    |> changeset(attrs)
    |> Repo.update()
  end

  defp params_to_attributes(params) do
    %{
      "name" => name,
      "watch_coin_input" => watch_coin_input,
      "watch_coin_output" => watch_coin_output,
      "watch_erc_20_input" => watch_erc_20_input,
      "watch_erc_20_output" => watch_erc_20_output,
      "watch_nft_input" => watch_nft_input,
      "watch_nft_output" => watch_nft_output,
      "notify_email" => notify_email
    } = params

    %{
      name: name,
      watch_coin_input: to_bool(watch_coin_input),
      watch_coin_output: to_bool(watch_coin_output),
      watch_erc_20_input: to_bool(watch_erc_20_input),
      watch_erc_20_output: to_bool(watch_erc_20_output),
      watch_erc_721_input: to_bool(watch_nft_input),
      watch_erc_721_output: to_bool(watch_nft_output),
      watch_erc_1155_input: to_bool(watch_nft_input),
      watch_erc_1155_output: to_bool(watch_nft_output),
      notify_email: to_bool(notify_email)
    }
  end

  defp to_bool("true"), do: true
  defp to_bool("false"), do: false

  def changeset(watchlist_address, attrs) do
    Changeset.change(watchlist_address, attrs)
  end
end
