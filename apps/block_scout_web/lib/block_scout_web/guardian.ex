defmodule BlockScoutWeb.Guardian do
  use Guardian, otp_app: :block_scout_web

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
