defmodule EsotericDisplayMgrWeb.DisplayLive.Form do
  use EsotericDisplayMgrWeb, :live_view

  alias EsotericDisplayMgr.Hardware
  alias EsotericDisplayMgr.Hardware.Display

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage display records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="display-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:label]} type="text" label="Label" />
        <.input field={@form[:ip_address]} type="text" label="Ip address" />
        <.input field={@form[:port]} type="number" label="Port" />
        <.input field={@form[:width]} type="number" label="Width" />
        <.input field={@form[:height]} type="number" label="Height" />
        <.input
          field={@form[:color_type]}
          type="select"
          label="Color type"
          options={["RGB", "RGBW", "HSL", "Grayscale"]}
          prompt="Select color type"
        />
        <.input
          field={@form[:bits_per_channel]}
          type="select"
          label="Bits per channel"
          options={[1, 4, 8, 16, 24, 32]}
          prompt="Select bit depth"
        />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Display</.button>
          <.button navigate={return_path(@current_scope, @return_to, @display)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    display = Hardware.get_display!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Display")
    |> assign(:display, display)
    |> assign(:form, to_form(Hardware.change_display(socket.assigns.current_scope, display)))
  end

  defp apply_action(socket, :new, _params) do
    display = %Display{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Display")
    |> assign(:display, display)
    |> assign(:form, to_form(Hardware.change_display(socket.assigns.current_scope, display)))
  end

  @impl true
  def handle_event("validate", %{"display" => display_params}, socket) do
    changeset =
      Hardware.change_display(
        socket.assigns.current_scope,
        socket.assigns.display,
        display_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"display" => display_params}, socket) do
    save_display(socket, socket.assigns.live_action, display_params)
  end

  defp save_display(socket, :edit, display_params) do
    case Hardware.update_display(
           socket.assigns.current_scope,
           socket.assigns.display,
           display_params
         ) do
      {:ok, display} ->
        {:noreply,
         socket
         |> put_flash(:info, "Display updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, display)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_display(socket, :new, display_params) do
    case Hardware.create_display(socket.assigns.current_scope, display_params) do
      {:ok, display} ->
        {:noreply,
         socket
         |> put_flash(:info, "Display created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, display)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _display), do: ~p"/admin/displays"
  defp return_path(_scope, "show", display), do: ~p"/admin/displays/#{display}"
end
