defmodule EsotericDisplayMgrWeb.MediaLive.Index do
  use EsotericDisplayMgrWeb, :live_view

  alias EsotericDisplayMgr.Media
  alias EsotericDisplayMgr.Media.Items
  alias EsotericDisplayMgr.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    can_protect? = Accounts.has_permission?(scope, "media:protect")

    socket =
      socket
      |> assign(:items, Media.list_items())
      |> assign(:can_protect?, can_protect?)
      |> assign(:page_title, "Media Library")
      |> assign(
        :form,
        to_form(%{"media_type" => "image", "marquee" => "none", "sizing" => "stretch"})
      )
      |> allow_upload(:media_file, accept: ~w(.png .jpg .jpeg .svg .gif), max_entries: 1)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"media_type" => _} = params, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("save", params, socket) do
    scope = socket.assigns.current_scope
    media_type = params["media_type"]

    content =
      if media_type == "text" do
        params["content"]
      else
        consume_uploaded_entries(socket, :media_file, fn %{path: path}, entry ->
          dest =
            Path.join([
              :code.priv_dir(:esoteric_display_mgr),
              "static",
              "uploads",
              "#{entry.uuid}-#{entry.client_name}"
            ])

          File.cp!(path, dest)
          {:ok, "/uploads/#{Path.basename(dest)}"}
        end)
        |> List.first()
      end

    attrs = Map.put(params, "content", content || "")

    case Media.create_item(scope, attrs) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Media added successfully.")
         |> assign(:items, Media.list_items())
         |> assign(
           :form,
           to_form(%{"media_type" => "image", "marquee" => "none", "sizing" => "stretch"})
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add media. Please check the form.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    item = Media.get_item!(id)

    case Media.delete_item(scope, item) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Media deleted.")
         |> assign(:items, Media.list_items())}

      {:error, :protected} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Cannot delete protected media without media:protect permission."
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete media.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h1 class="text-2xl font-bold text-base-content">Media Library</h1>
        <p class="text-base-content/70">Manage images and text elements for your displays.</p>
      </div>

      <div class="bg-base-100 shadow rounded-lg p-6 border border-base-200">
        <h2 class="text-lg font-semibold mb-4">Add New Media</h2>
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <.input
              type="select"
              field={@form[:media_type]}
              label="Media Type"
              options={[Image: "image", Text: "text"]}
            />

            <%= if @form[:media_type].value == "text" do %>
              <.input type="text" field={@form[:content]} label="Text Content" required />
            <% else %>
              <div class="fieldset">
                <label class="label mb-1">Upload File</label>
                <.live_file_input
                  upload={@uploads.media_file}
                  class="file-input file-input-bordered w-full"
                />
              </div>
            <% end %>

            <.input
              type="select"
              field={@form[:marquee]}
              label="Marquee"
              options={[
                None: "none",
                "Left to Right": "ltr",
                "Right to Left": "rtl",
                "Top to Bottom": "utd",
                "Bottom to Top": "dtu"
              ]}
            />
            <.input
              type="select"
              field={@form[:sizing]}
              label="Sizing"
              options={[Stretch: "stretch", Zoom: "zoom"]}
            />

            <div :if={@can_protect?} class="flex items-end pb-2">
              <.input type="checkbox" field={@form[:protected]} label="Protect from deletion" />
            </div>
          </div>
          <.button type="submit" class="btn btn-primary">Save Media</.button>
        </.form>
      </div>

      <div class="bg-base-100 shadow rounded-lg p-6 border border-base-200">
        <h2 class="text-lg font-semibold mb-4">Library</h2>
        <.table id="media-library" rows={@items}>
          <:col :let={item} label="Type">
            <span class="badge badge-neutral">{item.media_type}</span>
          </:col>
          <:col :let={item} label="Content">
            <%= if item.media_type == :text do %>
              <span class="font-mono text-sm">{item.content}</span>
            <% else %>
              <span class="text-xs text-base-content/70">{item.content}</span>
            <% end %>
          </:col>
          <:col :let={item} label="Modifiers">
            <span class="text-xs">Marquee: {item.marquee} | Resizing: {item.sizing}</span>
          </:col>
          <:col :let={item} label="Status">
            <%= if item.protected do %>
              <span class="badge badge-success badge-sm">Protected</span>
            <% else %>
              <span class="badge badge-warning badge-sm">Unprotected</span>
            <% end %>
          </:col>
          <:action :let={item}>
            <.button
              :if={!item.protected or @can_protect?}
              class="btn btn-error btn-sm"
              phx-click="delete"
              phx-value-id={item.id}
              data-confirm="Delete this media item?"
            >
              Delete
            </.button>
          </:action>
        </.table>
      </div>
    </div>
    """
  end
end
