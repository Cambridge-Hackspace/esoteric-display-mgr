defmodule EsotericDisplayMgrWeb.UserLive.Index do
  use EsotericDisplayMgrWeb, :live_view

  alias EsotericDisplayMgr.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Users
        <:actions>
          <.button variant="primary" navigate={~p"/admin/users/new"}>
            <.icon name="hero-plus" /> New User
          </.button>
        </:actions>
      </.header>

      <.table
        id="users"
        rows={@streams.users}
        row_click={fn {_id, user} -> JS.navigate(~p"/admin/users/#{user.id}/edit") end}
      >
        <:col :let={{_id, user}} label="Email">{user.email}</:col>
        <:col :let={{_id, user}} label="Roles">
          {Enum.join(Enum.map(user.roles || [], & &1.name), ", ")}
        </:col>
        <:action :let={{_id, user}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/users/#{user.id}/edit"}>Edit</.link>
          </div>
          <.link navigate={~p"/admin/users/#{user.id}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, user}}>
          <.link
            phx-click={JS.push("delete", value: %{id: user.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Accounts.subscribe_users(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Users")
     |> stream(:users, list_users(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(socket.assigns.current_scope, id)
    {:ok, _} = Accounts.delete_user(socket.assigns.current_scope, user)

    {:noreply, stream_delete(socket, :users, user)}
  end

  @impl true
  def handle_info({type, %EsotericDisplayMgr.Accounts.User{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :users, list_users(socket.assigns.current_scope), reset: true)}
  end

  defp list_users(current_scope) do
    Accounts.list_users(current_scope)
  end
end
