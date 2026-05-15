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
          <.button
            class="btn btn-xs"
            phx-click={
              JS.push("show_media", value: %{id: display.id}) |> show_modal("display_media_modal")
            }
          >
            Show Media
          </.button>
        </:action>
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

      <.modal id="display_media_modal">
        <h3 class="font-bold text-lg mb-4">
          Assigned Media - {@selected_display && @selected_display.label}
        </h3>

        <div class="flex flex-col gap-4">
          <%= if Enum.empty?(@display_media_items) and Enum.empty?(@display_stream_items) do %>
            <p class="text-base-content/70">No media or streams assigned to this display.</p>
          <% else %>
            <table class="table w-full">
              <thead>
                <tr>
                  <th>Type</th>
                  <th>Priority</th>
                  <th>Content / Info</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                <%= for item <- Enum.sort_by(@display_media_items ++ @display_stream_items, fn
        {:media, m} -> m.priority
      {:stream, s} -> s.priority
        end) do %>
                  <tr>
                    <%= case item do %>
                      <% {:media, m} -> %>
                        <td><span class="badge badge-neutral">Media ({m.media_type})</span></td>
                        <td>{m.priority}</td>
                        <td>{if m.media_type == :text, do: m.content, else: "(Image/GIF)"}</td>
                        <td>
                          <.button
                            class="btn btn-xs btn-error"
                            phx-click="disconnect_media"
                            phx-value-item_id={m.id}
                            data-confirm="Disconnect this media from the display?"
                          >
                            Disconnect
                          </.button>
                        </td>
                      <% {:stream, s} -> %>
                        <td><span class="badge badge-primary">Stream</span></td>
                        <td>{s.priority}</td>
                        <td>
                          Port: {s.port}<br /><span class="text-xs opacity-70">{s.owner_email}</span>
                        </td>
                        <td>
                          <.button
                            class="btn btn-xs btn-error"
                            phx-click="terminate_stream"
                            phx-value-port={s.port}
                            data-confirm="Terminate this stream entirely?"
                          >
                            Terminate
                          </.button>
                        </td>
                    <% end %>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>
      </.modal>
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
     |> assign(:selected_display, nil)
     |> assign(:display_media_items, [])
     |> assign(:display_stream_items, [])
     |> stream(:displays, list_displays(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    display = Hardware.get_display!(socket.assigns.current_scope, id)
    {:ok, _} = Hardware.delete_display(socket.assigns.current_scope, display)

    {:noreply, stream_delete(socket, :displays, display)}
  end

  @impl true
  def handle_event("show_media", %{"id" => id}, socket) do
    display = Hardware.get_display!(socket.assigns.current_scope, id)

    media_items =
      EsotericDisplayMgr.Media.list_items()
      |> Enum.filter(fn item -> Enum.any?(item.displays, &(&1.id == display.id)) end)
      |> Enum.map(&{:media, &1})

    streams =
      EsotericDisplayMgr.Stream.Manager.list_streams(socket.assigns.current_scope)
      |> Enum.filter(fn s -> display.label in s.display_labels end)
      |> Enum.map(&{:stream, &1})

    {:noreply,
     socket
     |> assign(:selected_display, display)
     |> assign(:display_media_items, media_items)
     |> assign(:display_stream_items, streams)}
  end

  @impl true
  def handle_event("disconnect_media", %{"item_id" => item_id}, socket) do
    item = EsotericDisplayMgr.Media.get_item!(item_id)
    display = socket.assigns.selected_display

    updated_display_ids =
      item.displays
      |> Enum.reject(&(&1.id == display.id))
      |> Enum.map(& &1.id)

    EsotericDisplayMgr.Media.update_item(socket.assigns.current_scope, item, %{
      "display_ids" => updated_display_ids
    })

    handle_event("show_media", %{"id" => display.id}, socket)
  end

  @impl true
  def handle_event("terminate_stream", %{"port" => port}, socket) do
    port = String.to_integer(port)

    case EsotericDisplayMgr.Stream.Manager.close_stream(socket.assigns.current_scope, port) do
      :ok ->
        Process.sleep(50)
        handle_event("show_media", %{"id" => socket.assigns.selected_display.id}, socket)

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cannot terminate stream.")}
    end
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
