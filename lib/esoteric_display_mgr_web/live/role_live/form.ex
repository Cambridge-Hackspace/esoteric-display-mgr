defmodule EsotericDisplayMgrWeb.RoleLive.Form do
  use EsotericDisplayMgrWeb, :live_view

  alias EsotericDisplayMgr.Accounts
  alias EsotericDisplayMgr.Accounts.Role

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage role records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="role-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <div class="mt-4">
          <label class="label"><span class="label-text font-semibold">Permissions</span></label>
          <div class="mt-3 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 bg-base-200 p-4 border border-base-300 rounded-lg">
            <label
              :for={perm <- EsotericDisplayMgr.Accounts.Permissions.all()}
              class="flex items-center gap-3 cursor-pointer"
            >
              <input
                type="checkbox"
                name={@form[:permissions].name <> "[]"}
                value={perm}
                checked={perm in (@form[:permissions].value || [])}
                class="checkbox checkbox-sm"
              />
              <span class="label-text font-mono">{perm}</span>
            </label>
          </div>
          <input type="hidden" name={@form[:permissions].name <> "[]"} value="" />
        </div>
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Role</.button>
          <.button navigate={return_path(@current_scope, @return_to, @role)}>Cancel</.button>
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
    role = Accounts.get_role!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Role")
    |> assign(:role, role)
    |> assign(:form, to_form(Accounts.change_role(socket.assigns.current_scope, role)))
  end

  defp apply_action(socket, :new, _params) do
    role = %Role{permissions: []}

    socket
    |> assign(:page_title, "New Role")
    |> assign(:role, role)
    |> assign(:form, to_form(Accounts.change_role(socket.assigns.current_scope, role)))
  end

  @impl true
  def handle_event("validate", %{"role" => role_params}, socket) do
    changeset =
      Accounts.change_role(socket.assigns.current_scope, socket.assigns.role, role_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"role" => role_params}, socket) do
    save_role(socket, socket.assigns.live_action, role_params)
  end

  defp save_role(socket, :edit, role_params) do
    case Accounts.update_role(socket.assigns.current_scope, socket.assigns.role, role_params) do
      {:ok, role} ->
        {:noreply,
         socket
         |> put_flash(:info, "Role updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, role)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_role(socket, :new, role_params) do
    case Accounts.create_role(socket.assigns.current_scope, role_params) do
      {:ok, role} ->
        {:noreply,
         socket
         |> put_flash(:info, "Role created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, role)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _role), do: ~p"/admin/roles"
  defp return_path(_scope, "show", role), do: ~p"/admin/roles/#{role.id}/edit"
end
