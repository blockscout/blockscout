defmodule ExplorerWeb.SocialMedia do
  @moduledoc """
  This module provides social media links
  """

  def links do
    Application.get_env(:explorer_web, __MODULE__, [])
  end
end
