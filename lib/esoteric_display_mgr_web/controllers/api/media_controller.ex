defmodule EsotericDisplayMgrWeb.API.MediaController do
  use EsotericDisplayMgrWeb, :controller

  alias EsotericDisplayMgr.Media
  alias EsotericDisplayMgr.Accounts

  plug :require_media_manage

  defp require_media_manage(conn, _opts) do
    scope = %EsotericDisplayMgr.Accounts.Scope{user: conn.assigns.current_user}

    if Accounts.has_permission?(scope, "media:manage") do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Unauthorized: Missing media:manage permission"})
      |> halt()
    end
  end

  def index(conn, _params) do
    items = Media.list_items()

    rendered_items =
      Enum.map(items, fn i ->
        %{
          id: i.id,
          media_type: i.media_type,
          content: i.content,
          marquee: i.marquee,
          sizing: i.sizing,
          protected: i.protected
        }
      end)

    json(conn, %{data: rendered_items})
  end

  def create(conn, params) do
    scope = %EsotericDisplayMgr.Accounts.Scope{user: conn.assigns.current_user}

    case Media.create_item(scope, params) do
      {:ok, item} ->
        json(conn, %{success: true, item: %{id: item.id, content: item.content}})

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid parameters"})

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Unauthorized"})
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = %EsotericDisplayMgr.Accounts.Scope{user: conn.assigns.current_user}

    case Media.get_item!(id) |> then(&Media.delete_item(scope, &1)) do
      {:ok, _} ->
        json(conn, %{success: true, message: "Deleted"})

      {:error, :protected} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Cannot delete protected media."})

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Unauthorized"})
    end
  end
end
