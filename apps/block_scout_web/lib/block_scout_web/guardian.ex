defmodule BlockScoutWeb.Guardian do
  @moduledoc """
    Module is responsible for selecting the info which will be included into jwt
  """
  use Guardian, otp_app: :block_scout_web

  alias BlockScoutWeb.Models.UserFromAuth
  alias Guardian.DB

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

  def after_encode_and_sign(resource, claims, token, _options) do
    with {:ok, _} <- DB.after_encode_and_sign(resource, claims["sub"], claims, token) do
      {:ok, token}
    end
  end

  def on_verify(claims, token, _options) do
    with {:ok, _} <- DB.on_verify(claims, token) do
      {:ok, claims}
    end
  end

  def on_refresh({old_token, old_claims}, {new_token, new_claims}, _options) do
    with {:ok, _, _} <- DB.on_refresh({old_token, old_claims}, {new_token, new_claims}) do
      {:ok, {old_token, old_claims}, {new_token, new_claims}}
    end
  end

  def on_revoke(claims, token, _options) do
    with {:ok, _} <- DB.on_revoke(claims, token) do
      {:ok, claims}
    end
  end
end
