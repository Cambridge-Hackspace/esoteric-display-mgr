defmodule EsotericDisplayMgrWeb.Plugs.ApiAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias EsotericDisplayMgr.Repo
  alias EsotericDisplayMgr.Accounts.User

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "x-api-key") do
      [api_key] ->
        case find_user_by_key(api_key) do
          %User{} = user ->
            assign(conn, :current_user, user)

          nil ->
            unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  def find_user_by_key(api_key) do
    User
    |> Repo.get_by(api_key: api_key)
    |> Repo.preload(:roles)
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: EsotericDisplayMgrWeb.ErrorJSON)
    |> render("401.json")
    |> halt()
  end
end
