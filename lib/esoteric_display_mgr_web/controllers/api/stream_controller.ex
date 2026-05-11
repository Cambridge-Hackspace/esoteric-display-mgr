defmodule EsotericDisplayMgrWeb.API.StreamController do
  use EsotericDisplayMgrWeb, :controller

  alias EsotericDisplayMgr.Hardware
  alias EsotericDisplayMgr.Stream.Manager
  alias EsotericDisplayMgr.Accounts

  plug :require_stream_connect when action in [:create, :delete]
  plug :require_displays_list when action in [:index]

  defp require_stream_connect(conn, _opts) do
    scope = %EsotericDisplayMgr.Accounts.Scope{user: conn.assigns.current_user}

    if Accounts.has_permission?(scope, "stream:connect") do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Unauthorized: Missing stream:connect permission"})
      |> halt()
    end
  end

  defp require_displays_list(conn, _opts) do
    scope = %EsotericDisplayMgr.Accounts.Scope{user: conn.assigns.current_user}

    if Accounts.has_permission?(scope, "displays:list") or
         Accounts.has_permission?(scope, "displays:manage") do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Unauthorized: Missing displays:list permission"})
      |> halt()
    end
  end

  def index(conn, _params) do
    scope = %EsotericDisplayMgr.Accounts.Scope{user: conn.assigns.current_user}
    displays = Hardware.list_displays(scope)

    rendered_displays =
      Enum.map(displays, fn d ->
        %{id: d.id, label: d.label, ip_address: d.ip_address, port: d.port}
      end)

    json(conn, %{data: rendered_displays})
  end

  def create(conn, %{"display_ids" => display_ids}) when is_list(display_ids) do
    scope = %EsotericDisplayMgr.Accounts.Scope{user: conn.assigns.current_user}
    user = scope.user
    displays = Enum.map(display_ids, &Hardware.get_display!(scope, &1))

    case Manager.open_stream(user, displays) do
      {:ok, port} ->
        json(conn, %{success: true, port: port, message: "UDP stream opened"})

      {:error, reason} ->
        require Logger
        Logger.error("failed to start UDP multiplexer: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to allocate UDP port"})
    end
  end

  def delete(conn, %{"port" => port}) do
    user = conn.assigns.current_user
    port = if is_binary(port), do: String.to_integer(port), else: port

    case Manager.close_stream(user, port) do
      :ok ->
        json(conn, %{success: true, message: "UDP stream closed"})

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "You do not have permission to close a stream you did not open."})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Stream not found (or it was already closed)."})
    end
  end
end
