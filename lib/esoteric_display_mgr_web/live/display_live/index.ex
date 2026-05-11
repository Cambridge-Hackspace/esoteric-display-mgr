defmodule EsotericDisplayMgrWeb.DisplayLive.Index do
  use EsotericDisplayMgrWeb, :live_view

  alias EsotericDisplayMgr.Hardware

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Displays
        <:actions>
          <.button variant="primary" navigate={~p"/admin/displays/new"}>
            <.icon name="hero-plus" /> New Display
          </.button>
        </:actions>
      </.header>

      <.table
        id="displays"
        rows={@streams.displays}
        row_click={fn {_id, display} -> JS.navigate(~p"/admin/displays/#{display}") end}
      >
        <:col :let={{_id, display}} label="Label">{display.label}</:col>
        <:col :let={{_id, display}} label="Ip address">{display.ip_address}</:col>
        <:col :let={{_id, display}} label="Port">{display.port}</:col>
        <:col :let={{_id, display}} label="Width">{display.width}</:col>
        <:col :let={{_id, display}} label="Height">{display.height}</:col>
        <:col :let={{_id, display}} label="Color type">{display.color_type}</:col>
        <:col :let={{_id, display}} label="Bits per channel">{display.bits_per_channel}</:col>
        <:action :let={{_id, display}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/displays/#{display}"}>Show</.link>
          </div>
          <.link navigate={~p"/admin/displays/#{display}"}>Edit</.link>
        </:action>
        <:action :let={{id, display}}>
          <.link
            phx-click={JS.push("delete", value: %{id: display.id}) |> hide("##{id}")}
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
      Hardware.subscribe_displays(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Displays")
     |> stream(:displays, list_displays(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    display = Hardware.get_display!(socket.assigns.current_scope, id)
    {:ok, _} = Hardware.delete_display(socket.assigns.current_scope, display)

    {:noreply, stream_delete(socket, :displays, display)}
  end

  @impl true
  def handle_info({type, %EsotericDisplayMgr.Hardware.Display{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(socket, :displays, list_displays(socket.assigns.current_scope), reset: true)}
  end

  defp list_displays(current_scope) do
    Hardware.list_displays(current_scope)
  end
end
