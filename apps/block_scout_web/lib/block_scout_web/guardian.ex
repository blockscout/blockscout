defmodule BlockScoutWeb.Guardian do
  @moduledoc """
    Module is responsible for selecting the info which will be included into jwt
  """
  use Guardian, otp_app: :block_scout_web

  alias BlockScoutWeb.Models.UserFromAuth

  def subject_for_token(%{uid: uid}, _claims) do
    sub = to_string(uid)
    {:ok, sub}
  end

  def subject_for_token(_, _) do
    {:error, :missing_id_field}
  end

  def resource_from_claims(%{"sub" => uid}) do
    resource = UserFromAuth.find_identity(uid)
    {:ok, resource}
  end

  def resource_from_claims(_claims) do
    {:error, :invalid_data}
  end
end
