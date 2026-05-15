defmodule EsotericDisplayMgrWeb.StreamLive.Index do
  use EsotericDisplayMgrWeb, :live_view

  alias EsotericDisplayMgr.Stream.Manager
  alias EsotericDisplayMgr.Hardware
  alias EsotericDisplayMgr.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    # stream:manage implies stream:connect
    can_manage? = Accounts.has_permission?(scope, "stream:manage")
    can_connect? = can_manage? || Accounts.has_permission?(scope, "stream:connect")

    if can_connect? do
      if connected?(socket), do: :timer.send_interval(2000, :refresh_streams)

      displays = Hardware.list_displays(scope)

      socket =
        socket
        |> assign(:can_manage?, can_manage?)
        |> assign(:displays, displays)
        |> assign(:active_streams, Manager.list_streams(scope))
        |> assign(
          :form,
          to_form(%{"display_ids" => [], "priority" => Accounts.get_priority_cap(scope)})
        )
        |> assign(:page_title, "Manage Streams")

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized: Missing stream:connect permission")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(:refresh_streams, socket) do
    {:noreply,
     assign(socket, :active_streams, Manager.list_streams(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("open_stream", %{"display_ids" => display_ids, "priority" => priority}, socket) do
    scope = socket.assigns.current_scope
    display_ids = Enum.reject(display_ids, &(&1 == ""))
    {priority_int, _} = Integer.parse(priority)

    if Enum.empty?(display_ids) do
      {:noreply, put_flash(socket, :error, "You must select at least one display.")}
    else
      displays = Enum.map(display_ids, &Hardware.get_display!(scope, &1))

      case Manager.open_stream(scope.user, displays, priority_int) do
        {:ok, port} ->
          {:noreply,
           socket
           |> put_flash(:info, "UDP stream opened on port #{port}")
           |> assign(:active_streams, Manager.list_streams(scope))}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to allocate UDP port.")}
      end
    end
  end

  @impl true
  def handle_event("close_stream", %{"port" => port}, socket) do
    scope = socket.assigns.current_scope
    port = String.to_integer(port)

    case Manager.close_stream(scope, port) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream on port #{port} closed.")
         |> assign(:active_streams, Manager.list_streams(scope))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You do not have permission to close this stream.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Stream not found (or it's already closed).")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h1 class="text-2xl font-bold text-base-content">Manage UDP Streams</h1>
        <p class="text-base-content/70">Establish an ephemeral UDP port for display dispatch.</p>
      </div>

      <div class="bg-base-100 shadow rounded-lg p-6">
        <h2 class="text-lg font-semibold mb-4">Open New Stream</h2>
        <.form for={@form} phx-submit="open_stream">
          <div class="mb-4">
            <.input
              type="number"
              field={@form[:priority]}
              label={"Priority (Cap: #{EsotericDisplayMgr.Accounts.get_priority_cap(@current_scope)})"}
              min={EsotericDisplayMgr.Accounts.get_priority_cap(@current_scope)}
              max="7"
            />
          </div>
          <div class="mb-4">
            <label class="block text-sm font-medium mb-2">Select Displays</label>
            <div class="space-y-2 max-h-48 overflow-y-auto border border-base-300 rounded p-3">
              <%= for display <- @displays do %>
                <label class="flex items-center space-x-3">
                  <input
                    type="checkbox"
                    name="display_ids[]"
                    value={display.id}
                    class="checkbox checkbox-primary checkbox-sm"
                  />
                  <span>{display.label} ({display.ip_address}:{display.port})</span>
                </label>
              <% end %>
            </div>
          </div>
          <.button type="submit" class="btn btn-primary" phx-disable-with="Opening...">
            Open Stream
          </.button>
        </.form>
      </div>

      <div class="bg-base-100 shadow rounded-lg p-6 border border-base-200">
        <h2 class="text-lg font-semibold mb-4">Active Streams</h2>

        <%= if Enum.empty?(@active_streams) do %>
          <p class="text-base-content/70 italic">No active streams.</p>
        <% else %>
          <div class="overflow-x-auto">
            <.table id="active-streams" rows={@active_streams}>
              <:col :let={stream} label="Port"><span class="font-mono">{stream.port}</span></:col>
              <:col :let={stream} label="Owner">{stream.owner_email}</:col>
              <:col :let={stream} label="Target">
                <span class="text-base-content/70">{Enum.join(stream.display_labels, ", ")}</span>
              </:col>
              <:action :let={stream}>
                <.button
                  class="btn btn-error btn-sm"
                  phx-click="close_stream"
                  phx-value-port={stream.port}
                  data-confirm="Are you sure you want to close this stream?"
                >
                  Close
                </.button>
              </:action>
            </.table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
