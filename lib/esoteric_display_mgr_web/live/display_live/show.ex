defmodule EsotericDisplayMgrWeb.DisplayLive.Show do
  use EsotericDisplayMgrWeb, :live_view

  alias EsotericDisplayMgr.Hardware

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Display {@display.id}
        <:subtitle>This is a display record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/displays"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/displays/#{@display}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit display
          </.button>
        </:actions>
      </.header>

      <div class="mt-8 bg-black p-4 rounded-lg w-full overflow-hidden flex justify-center">
        <canvas
          id="canvas-preview"
          data-width={@display.width}
          data-height={@display.height}
          data-bits={@display.bits_per_channel}
          phx-hook="DDPPlayer"
          class="border border-base-300 bg-black"
          style={"width: 100%; min-width: 250px; max-height: 50vh; aspect-ratio: #{@display.width} / #{@display.height}; image-rendering: pixelated; object-fit: contain;"}
        >
        </canvas>
      </div>

      <.list>
        <:item title="Label">{@display.label}</:item>
        <:item title="Ip address">{@display.ip_address}</:item>
        <:item title="Port">{@display.port}</:item>
        <:item title="Width">{@display.width}</:item>
        <:item title="Height">{@display.height}</:item>
        <:item title="Color type">{@display.color_type}</:item>
        <:item title="Bits per channel">{@display.bits_per_channel}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Hardware.subscribe_displays(socket.assigns.current_scope)
      Phoenix.PubSub.subscribe(EsotericDisplayMgr.PubSub, "display_preview:#{id}")
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Display")
     |> assign(:display, Hardware.get_display!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info({:preview_packet, packet}, socket) do
    {:noreply, push_event(socket, "ddp-frame-canvas-preview", %{frames: [Base.encode64(packet)]})}
  end

  @impl true
  def handle_info(
        {:updated, %EsotericDisplayMgr.Hardware.Display{id: id} = display},
        %{assigns: %{display: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :display, display)}
  end

  def handle_info(
        {:deleted, %EsotericDisplayMgr.Hardware.Display{id: id}},
        %{assigns: %{display: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current display was deleted.")
     |> push_navigate(to: ~p"/admin/displays")}
  end

  def handle_info({type, %EsotericDisplayMgr.Hardware.Display{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
