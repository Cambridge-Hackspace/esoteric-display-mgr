defmodule EsotericDisplayMgrWeb.UserLive.Form do
  use EsotericDisplayMgrWeb, :live_view

  alias EsotericDisplayMgr.Accounts
  alias EsotericDisplayMgr.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage user records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="user-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} type="text" label="Email" />
        <.input
          :if={@live_action == :new}
          field={@form[:password]}
          type="password"
          label="Temporary Password"
          required
        />

        <div class="mt-4">
          <label class="label"><span class="label-text font-semibold">Assigned Roles</span></label>
          <div class="mt-3 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 bg-base-200 p-4 border border-base-300 rounded-lg">
            <label :for={role <- @available_roles} class="flex items-center gap-3 cursor-pointer">
              <input
                type="checkbox"
                name="user[role_ids][]"
                value={role.id}
                checked={role.id in Enum.map(@user.roles || [], & &1.id)}
                class="checkbox checkbox-sm"
              />
              <span class="label-text font-medium">{role.name}</span>
            </label>
          </div>
          <input type="hidden" name="user[role_ids][]" value="" />
        </div>
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save User</.button>
          <.button navigate={return_path(@current_scope, @return_to, @user)}>Cancel</.button>
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
    user = Accounts.get_user!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, user)
    |> assign(:available_roles, Accounts.list_roles())
    |> assign(:form, to_form(Accounts.change_user(socket.assigns.current_scope, user)))
  end

  defp apply_action(socket, :new, _params) do
    user = %User{roles: []}

    socket
    |> assign(:page_title, "New User")
    |> assign(:user, user)
    |> assign(:available_roles, Accounts.list_roles())
    |> assign(:form, to_form(Accounts.change_user(socket.assigns.current_scope, user)))
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user(socket.assigns.current_scope, socket.assigns.user, user_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.live_action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    role_ids = Map.get(user_params, "role_ids", [])

    case Accounts.update_user(socket.assigns.current_scope, socket.assigns.user, user_params) do
      {:ok, user} ->
        {:ok, _} = Accounts.update_user_roles(user, role_ids, socket.assigns.current_scope.user)

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, user)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_user(socket, :new, user_params) do
    role_ids = Map.get(user_params, "role_ids", [])

    case Accounts.create_user_by_admin(socket.assigns.current_scope, user_params) do
      {:ok, user} ->
        {:ok, _} = Accounts.update_user_roles(user, role_ids, socket.assigns.current_scope.user)

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, user)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _user), do: ~p"/admin/users"
  defp return_path(_scope, "show", user), do: ~p"/admin/users/#{user.id}/edit"
end
