defmodule ConfigHelper do
  def hackney_options() do
    basic_auth_user = System.get_env("ETHEREUM_JSONRPC_USER", "")
    basic_auth_pass = System.get_env("ETHEREUM_JSONRPC_PASSWORD", nil)

    hackney_opts =
      [pool: :ethereum_jsonrpc]
      |> (&if(System.get_env("ETHEREUM_JSONRPC_HTTP_INSECURE", "") == "true", do: [:insecure] ++ &1, else: &1)).()
      |> (&if(basic_auth_user != "" && !is_nil(basic_auth_pass),
            do: [basic_auth: {basic_auth_user, basic_auth_pass}] ++ &1,
            else: &1
          )).()
  end
end
