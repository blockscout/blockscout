defmodule BlockScoutWeb.ErrorView do
  use BlockScoutWeb, :view

  # when type in ["json", "html"]
  def render("404." <> _type, _assigns) do
    "Page not found"
  end

  def render("400." <> _type, _assigns) do
    "Bad request"
  end

  def render("401." <> _type, _assigns) do
    "Unauthorized"
  end

  def render("403." <> _type, _assigns) do
    "Forbidden"
  end

  def render("422." <> _type, _assigns) do
    "Unprocessable entity"
  end

  def render("500." <> _type, _assigns) do
    "Internal server error"
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render("500.html", assigns)
  end
end
