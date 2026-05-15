defmodule EsotericDisplayMgrWeb.MediaLive.Index do
  use EsotericDisplayMgrWeb, :live_view

  alias EsotericDisplayMgr.Media
  alias EsotericDisplayMgr.Hardware
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
      |> assign(:expanded_preview, nil)
      |> assign(:simulating_item, nil)
      |> assign(:loading_simulation, false)
      |> assign(:selected_display_id, nil)
      |> assign(:current_display, nil)
      |> assign(:displays, Hardware.list_displays(scope))
      |> assign(
        :form,
        to_form(%{
          "media_type" => "image",
          "marquee" => "none",
          "sizing" => "stretch",
          "priority" => Accounts.get_priority_cap(scope),
          "display_ids" => []
        })
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

    attrs =
      if attrs["media_type"] == "image" and content do
        if String.downcase(Path.extname(content)) == ".gif" do
          attrs
          |> Map.put("media_type", "gif")
          |> Map.put("marquee", "none")
        else
          attrs
        end
      else
        attrs
      end

    case Media.create_item(scope, attrs) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Media added successfully.")
         |> assign(:items, Media.list_items())
         |> assign(
           :form,
           to_form(%{
             "media_type" => "image",
             "marquee" => "none",
             "sizing" => "stretch",
             "priority" => Accounts.get_priority_cap(scope),
             "display_ids" => []
           })
         )}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add media. Please check the form.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  @impl true
  def handle_event("update_media", params, socket) do
    scope = socket.assigns.current_scope
    id = String.to_integer(params["item_id"])
    item = Media.get_item!(id)

    case Media.update_item(scope, item, params) do
      {:ok, updated_item} ->
        socket = assign(socket, :items, Media.list_items())

        socket =
          if socket.assigns.simulating_item == updated_item.id and socket.assigns.current_display do
            Task.async(fn ->
              frames =
                EsotericDisplayMgr.Media.Renderer.generate_ddp_stream(
                  updated_item,
                  socket.assigns.current_display
                )

              {:simulation_frames, updated_item.id, frames}
            end)

            assign(socket, :loading_simulation, true)
          else
            socket
          end

        {:noreply, socket}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Unauthorized.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update media.")}
    end
  end

  @impl true
  def handle_event("toggle_preview", %{"id" => id}, socket) do
    id = String.to_integer(id)

    if socket.assigns.expanded_preview == id do
      {:noreply, assign(socket, :expanded_preview, nil)}
    else
      {:noreply, assign(socket, expanded_preview: id, simulating_item: nil)}
    end
  end

  @impl true
  def handle_event("toggle_simulate", %{"id" => id}, socket) do
    id = String.to_integer(id)

    if socket.assigns.simulating_item == id do
      {:noreply, assign(socket, simulating_item: nil, loading_simulation: false)}
    else
      {:noreply,
       assign(socket,
         simulating_item: id,
         expanded_preview: nil,
         selected_display_id: nil,
         current_display: nil,
         loading_simulation: false
       )}
    end
  end

  @impl true
  def handle_event("select_display", %{"display_id" => display_id}, socket) do
    if display_id == "" do
      {:noreply,
       assign(socket, selected_display_id: nil, current_display: nil, loading_simulation: false)}
    else
      display_id = String.to_integer(display_id)
      display = Hardware.get_display!(socket.assigns.current_scope, display_id)
      item = Media.get_item!(socket.assigns.simulating_item)

      Task.async(fn ->
        frames = EsotericDisplayMgr.Media.Renderer.generate_ddp_stream(item, display)
        {:simulation_frames, item.id, frames}
      end)

      {:noreply,
       assign(socket,
         selected_display_id: display_id,
         current_display: display,
         loading_simulation: true
       )}
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
           "Cannot delete protected media. Please unprotect it first."
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete media.")}
    end
  end

  @impl true
  def handle_info({ref, {:simulation_frames, item_id, frames}}, socket) do
    Process.demonitor(ref, [:flush])

    socket =
      socket
      |> push_event("ddp-frame-canvas-#{item_id}", %{frames: frames})
      |> assign(:loading_simulation, false)

    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, assign(socket, :loading_simulation, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8 pb-32">
      <div>
        <h1 class="text-2xl font-bold text-base-content">Media Library</h1>
        <p class="text-base-content/70">Manage images and text elements for your displays.</p>
      </div>

      <div class="bg-base-100 shadow rounded-lg p-6 border border-base-200">
        <h2 class="text-lg font-semibold mb-4">Add New Media</h2>
        <.form
          for={@form}
          phx-change="validate"
          phx-submit="save"
          id="new-media-form"
          class="space-y-4"
        >
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

            <% is_gif_upload? =
              @form[:media_type].value == "image" and
                Enum.any?(@uploads.media_file.entries, fn entry ->
                  String.ends_with?(String.downcase(entry.client_name), ".gif")
                end) %>

            <%= if is_gif_upload? do %>
              <input type="hidden" name={@form[:marquee].name} value="none" />
              <.input
                type="select"
                field={@form[:marquee]}
                label="Marquee"
                options={[None: "none"]}
                disabled
              />
            <% else %>
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
            <% end %>
            <.input
              type="select"
              field={@form[:sizing]}
              label="Sizing"
              options={[Stretch: "stretch", Zoom: "zoom", Crop: "crop"]}
            />

            <.input
              type="number"
              field={@form[:priority]}
              label={"Priority (Cap: #{EsotericDisplayMgr.Accounts.get_priority_cap(@current_scope)})"}
              min={EsotericDisplayMgr.Accounts.get_priority_cap(@current_scope)}
              max="7"
            />

            <div class="fieldset">
              <label class="label mb-1">Assign Displays</label>
              <button
                type="button"
                class="btn btn-sm btn-outline w-fit"
                phx-click={show_modal("new_display_modal")}
              >
                Select Devices
              </button>

              <.modal id="new_display_modal">
                <h3 class="font-bold text-lg mb-4">Assign Displays</h3>
                <div class="flex flex-col gap-2 max-h-64 overflow-y-auto">
                  <input
                    type="hidden"
                    name={@form[:display_ids].name <> "[]"}
                    value=""
                    form="new-media-form"
                  />
                  <%= for display <- @displays do %>
                    <% checked =
                      to_string(display.id) in if is_list(@form[:display_ids].value),
                        do: Enum.map(@form[:display_ids].value, &to_string/1),
                        else: [] %>
                    <label class="cursor-pointer label justify-start gap-3 p-2 hover:bg-base-200 rounded-lg">
                      <input
                        type="checkbox"
                        name={@form[:display_ids].name <> "[]"}
                        value={display.id}
                        checked={checked}
                        class="checkbox checkbox-primary"
                        form="new-media-form"
                      />
                      <span class="label-text">{display.label}</span>
                    </label>
                  <% end %>
                </div>
                <div class="modal-action">
                  <button
                    type="button"
                    class="btn btn-primary"
                    phx-click={hide_modal("new_display_modal")}
                  >
                    Done
                  </button>
                </div>
              </.modal>
            </div>

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
              <form phx-change="update_media" phx-submit="update_media">
                <input type="hidden" name="item_id" value={item.id} />
                <input
                  id={"item-content-#{item.id}"}
                  type="text"
                  name="content"
                  value={item.content}
                  class="input input-bordered input-sm font-mono w-full min-w-[200px]"
                />
              </form>
            <% else %>
              <span class="text-xs text-base-content/70">{item.content}</span>
            <% end %>

            <div
              :if={@expanded_preview == item.id}
              class="mt-4 p-4 bg-base-200 rounded-lg shadow-inner"
            >
              <%= if item.media_type == :text do %>
                <p class="text-xl font-bold">{item.content}</p>
              <% else %>
                <img src={item.content} class="max-h-48 object-contain rounded" />
              <% end %>
            </div>

            <div
              :if={@simulating_item == item.id}
              class="mt-4 p-4 bg-base-200 rounded-lg shadow-inner"
            >
              <form phx-change="select_display" class="mb-4">
                <select name="display_id" class="select select-bordered select-sm">
                  <option value="">Select a physical display...</option>
                  <%= for display <- @displays do %>
                    <option value={display.id} selected={@selected_display_id == display.id}>
                      {display.label} ({display.width}x{display.height})
                    </option>
                  <% end %>
                </select>
              </form>
              <div :if={@loading_simulation} class="flex justify-center p-8">
                <span class="loading loading-spinner loading-lg text-primary"></span>
              </div>

              <div
                class={[
                  "mt-4 flex justify-center bg-black p-4 rounded-lg w-full overflow-hidden",
                  @loading_simulation && "hidden"
                ]}
                style={if !@selected_display_id || !@current_display, do: "display: none;"}
              >
                <canvas
                  id={"canvas-#{item.id}"}
                  data-width={if @current_display, do: @current_display.width, else: 0}
                  data-height={if @current_display, do: @current_display.height, else: 0}
                  data-bits={if @current_display, do: @current_display.bits_per_channel, else: 8}
                  phx-hook="DDPPlayer"
                  class="border border-base-300 bg-black"
                  style={"width: 100%; min-width: 250px; max-height: 50vh; aspect-ratio: #{if @current_display, do: @current_display.width, else: 1} / #{if @current_display, do: @current_display.height, else: 1}; image-rendering: pixelated; object-fit: contain;"}
                >
                </canvas>
              </div>
            </div>
          </:col>
          <:col :let={item} label="Modifiers">
            <div class="flex flex-col gap-2">
              <form
                phx-change="update_media"
                id={"edit-media-form-#{item.id}"}
                class="flex flex-col gap-2"
              >
                <input type="hidden" name="item_id" value={item.id} />
                <input
                  type="number"
                  name="priority"
                  value={item.priority}
                  class="input input-bordered input-xs"
                  min={EsotericDisplayMgr.Accounts.get_priority_cap(@current_scope)}
                  max="7"
                />
                <%= if item.media_type == :gif do %>
                  <input type="hidden" name="marquee" value="none" />
                  <select class="select select-bordered select-xs w-full max-w-xs" disabled>
                    <option value="none" selected>None</option>
                  </select>
                <% else %>
                  <select name="marquee" class="select select-bordered select-xs w-full max-w-xs">
                    <option value="none" selected={item.marquee == :none}>None</option>
                    <option value="ltr" selected={item.marquee == :ltr}>Left to Right</option>
                    <option value="rtl" selected={item.marquee == :rtl}>Right to Left</option>
                    <option value="utd" selected={item.marquee == :utd}>Top to Bottom</option>
                    <option value="dtu" selected={item.marquee == :dtu}>Bottom to Top</option>
                  </select>
                <% end %>
                <select name="sizing" class="select select-bordered select-xs w-full max-w-xs">
                  <option value="stretch" selected={item.sizing == :stretch}>Stretch</option>
                  <option value="zoom" selected={item.sizing == :zoom}>Zoom</option>
                  <option value="crop" selected={item.sizing == :crop}>Crop</option>
                </select>
              </form>

              <button
                type="button"
                class="btn btn-xs btn-outline mt-1 w-full"
                onclick={"document.getElementById('edit_display_modal_#{item.id}').showModal()"}
              >
                Select Devices
              </button>
              <dialog id={"edit_display_modal_#{item.id}"} class="modal">
                <div class="modal-box">
                  <form
                    phx-submit="update_media"
                    onsubmit={"document.getElementById('edit_display_modal_#{item.id}').close()"}
                  >
                    <input type="hidden" name="item_id" value={item.id} />
                    <h3 class="font-bold text-lg mb-4">Assign Display</h3>
                    <div class="flex flex-col gap-2 max-h-64 overflow-y-auto">
                      <input
                        type="hidden"
                        name="display_ids[]"
                        value=""
                      />
                      <%= for display <- @displays do %>
                        <% assigned? = Enum.any?(item.displays, &(&1.id == display.id)) %>
                        <label class="cursor-pointer label justify-start gap-3 p-2 hover:bg-base-200 rounded-lg">
                          <input
                            type="checkbox"
                            name="display_ids[]"
                            value={display.id}
                            checked={assigned?}
                            class="checkbox checkbox-primary"
                          />
                          <span class="label-text">{display.label}</span>
                        </label>
                      <% end %>
                    </div>
                    <div class="modal-action">
                      <button type="submit" class="btn btn-primary">Done</button>
                      <button
                        type="button"
                        class="btn"
                        onclick={"document.getElementById('edit_display_modal_#{item.id}').close()"}
                      >
                        Cancel
                      </button>
                    </div>
                  </form>
                </div>
                <form method="dialog" class="modal-backdrop">
                  <button>close</button>
                </form>
              </dialog>
            </div>
          </:col>
          <:col :let={item} label="Status">
            <form phx-change="update_media">
              <input type="hidden" name="item_id" value={item.id} />
              <input type="hidden" name="protected" value="false" />
              <%= if @can_protect? do %>
                <label class="label cursor-pointer p-0 justify-start gap-2">
                  <input
                    type="checkbox"
                    name="protected"
                    value="true"
                    checked={item.protected}
                    class="checkbox checkbox-xs checkbox-success"
                  />
                  <span class="label-text text-xs">Protected</span>
                </label>
              <% else %>
                <%= if item.protected do %>
                  <span class="badge badge-success badge-sm">Protected</span>
                <% else %>
                  <span class="badge badge-warning badge-sm">Unprotected</span>
                <% end %>
              <% end %>
            </form>
          </:col>
          <:action :let={item}>
            <.button
              class="btn btn-ghost btn-sm"
              phx-click="toggle_preview"
              phx-value-id={item.id}
            >
              {if @expanded_preview == item.id, do: "Hide", else: "Preview"}
            </.button>
            <.button
              class="btn btn-primary btn-sm"
              phx-click="toggle_simulate"
              phx-value-id={item.id}
            >
              Simulate
            </.button>
            <.button
              :if={!item.protected}
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
