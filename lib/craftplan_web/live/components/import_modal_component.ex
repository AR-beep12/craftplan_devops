defmodule CraftplanWeb.ImportModalComponent do
  @moduledoc """
  Reusable CSV Import modal as a self-contained LiveComponent.

  Features:
  - Sticky stepper with backward navigation by clicking earlier steps
  - Provide CSV (paste or upload), Mapping, Import wizard
  - Mapping/Preview/Errors tabbed view to reduce scrolling
  - Footer actions rendered via the underlying modal component
  - Emits {:import_modal, :closed} message to the parent on close
  """
  use CraftplanWeb, :live_component

  alias Phoenix.LiveView.UploadConfig

  # Match by extension: browsers report all kinds of MIME types for a CSV
  # ("text/plain", "application/vnd.ms-excel", or none at all), and LiveView
  # accepts an entry as soon as its extension matches. The content itself is
  # validated later, on the mapping step.
  @accepted_csv_types [".csv", ".txt"]

  # Internal assigns defaults
  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign_new(:csv_form, fn -> to_form(%{}) end)
      |> assign_new(:csv_export_form, fn -> to_form(%{}) end)
      |> assign_new(:csv_preview, fn -> nil end)
      |> assign_new(:csv_headers, fn -> [] end)
      |> assign_new(:csv_rows, fn -> [] end)
      |> assign_new(:csv_mapping, fn -> %{} end)
      |> assign_new(:csv_errors, fn -> [] end)
      |> assign_new(:csv_delimiter, fn -> "," end)
      |> assign_new(:dry_run_summary, fn -> nil end)
      |> assign_new(:wizard_step, fn -> :provide end)
      |> assign_new(:map_view_tab, fn -> :mapping end)

    # Configure upload once per parent view.
    socket =
      if socket.assigns[:_upload_init] do
        socket
      else
        socket
        |> allow_upload(:csv,
          accept: @accepted_csv_types,
          max_entries: 1,
          progress: &handle_csv_progress/3
        )
        |> assign(:_upload_init, true)
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:config, entity_config(assigns[:entity]))
      |> assign(:csv_upload, assigns.uploads[:csv])
      |> assign(:csv_entries, csv_entries(assigns.uploads[:csv]))

    ~H"""
    <div id={@id <> "-wrap"}>
      <.modal
        :if={@show}
        id={@id}
        title={"Importar " <> @config.label}
        show={true}
        on_cancel={JS.push("wizard_close", target: @myself)}
      >
        <div>
          <div
            phx-target={@myself}
            class="bg-white/95 sticky top-0 z-20 -mx-6 mb-4 px-6 py-3 backdrop-blur supports-[backdrop-filter]:bg-white/60"
          >
            <.stepper
              steps={["Cargar CSV", "Mapeo", "Importar"]}
              current={wizard_label(@wizard_step)}
              goto_event="wizard_goto"
            />
          </div>

          <div class="mb-4 text-sm text-stone-700">
            <div class="font-medium">Este es el formato:</div>

            <div :for={line <- @config.instructions}>{line}</div>

            <div class="mt-2">
              <.link
                id="csv-template-download"
                href={"/manage/settings/csv/template/#{@config.key}"}
                target="_blank"
                class="inline-flex items-center justify-center rounded-lg border border-stone-300 bg-white px-3 py-2 text-sm font-medium text-stone-800 shadow-sm transition hover:border-primary-400 hover:text-primary-700"
              >
                Descargar plantilla
              </.link>
            </div>
          </div>

          <.form
            :if={@wizard_step == :provide}
            for={@csv_form}
            id="csv-select-form"
            phx-target={@myself}
            phx-change="csv_select_change"
            phx-submit="csv_import"
          >
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <.input type="text" name="delimiter" label="Delimitador" value={@csv_delimiter || ","} />
              <.input
                type="checkbox"
                name="dry_run"
                label="Ejecución de prueba (vista previa)"
                checked
              />
              <div class="sm:col-span-2">
                <.input type="textarea" name="csv_content" label="Pegar CSV" value="" />
              </div>

              <div class="sm:col-span-2">
                <!-- Upload area. phx-drop-target is required by LiveView, without it
                     dropping a file on this label is silently discarded. -->
                <label class="mb-1 block text-sm font-medium text-stone-700">O elige un archivo…</label>
                <label
                  id="csv-dropzone"
                  for={@csv_upload.ref}
                  phx-drop-target={@csv_upload.ref}
                  class="min-h-[120px] relative flex cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed border-stone-300 bg-stone-50 px-4 py-6 text-center transition phx-drop-target-active:border-primary-500 phx-drop-target-active:bg-primary-50 hover:border-primary-400 hover:bg-primary-50/30"
                >
                  <.live_file_input
                    upload={@csv_upload}
                    class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
                  />
                  <.icon name="hero-arrow-up-tray" class="h-8 w-8 text-stone-400" />
                  <p class="mt-2 text-sm font-medium text-stone-600">
                    Haz clic para seleccionar un archivo CSV
                  </p>
                  <p class="mt-1 text-xs text-stone-400">
                    o arrastra y suelta aquí
                  </p>
                </label>

                <ul id="csv-upload-entries" class="mt-2 space-y-1">
                  <li
                    :for={entry <- @csv_entries}
                    id={"csv-upload-#{entry.ref}"}
                    class="flex items-center gap-2 rounded-md border border-stone-200 bg-white px-3 py-2 text-xs"
                  >
                    <.icon name="hero-document-text" class="h-4 w-4 shrink-0 text-stone-400" />
                    <span class="flex-1 truncate font-medium text-stone-700">
                      {entry.client_name}
                    </span>

                    <%= case entry.status do %>
                      <% {:ready, _} -> %>
                        <span id={"csv-upload-#{entry.ref}-ready"} class="text-emerald-700">
                          Listo — pulsa Siguiente
                        </span>
                      <% {:rejected, message} -> %>
                        <span id={"csv-upload-#{entry.ref}-error"} class="text-red-700">
                          {message}
                        </span>
                      <% {:uploading, _} -> %>
                        <progress
                          id={"csv-upload-#{entry.ref}-progress"}
                          value={entry.progress}
                          max="100"
                          class="h-1.5 w-20"
                        ></progress>
                        <span class="tabular-nums text-stone-500">{entry.progress}%</span>
                    <% end %>

                    <button
                      id={"csv-upload-#{entry.ref}-remove"}
                      type="button"
                      phx-target={@myself}
                      phx-click="csv_clear_upload"
                      phx-value-ref={entry.ref}
                      aria-label="Quitar archivo"
                      class="text-stone-400 transition hover:text-stone-700"
                    >
                      <.icon name="hero-x-mark-solid" class="h-4 w-4" />
                    </button>
                  </li>
                </ul>
              </div>
            </div>
          </.form>

          <div :if={@wizard_step in [:map, :import]} class="mt-6">
            <div class="mb-2 flex items-center justify-between">
              <h4 class="font-medium">Datos</h4>

              <div :if={@csv_errors && @csv_errors != []} class="text-xs text-red-700">
                {length(@csv_errors)} error(es)
              </div>
            </div>

            <div class="mb-2">
              <div
                role="tablist"
                aria-orientation="horizontal"
                class="bg-stone-200/50 inline-flex h-9 rounded-lg p-1"
              >
                <button
                  type="button"
                  phx-target={@myself}
                  phx-click="map_set_tab"
                  phx-value-tab="mapping"
                  class={[
                    "inline-flex items-center justify-center whitespace-nowrap rounded-md border px-3 py-1 text-sm font-medium",
                    @map_view_tab == :mapping && "border-stone-300 bg-stone-50 shadow",
                    @map_view_tab != :mapping && "border-transparent"
                  ]}
                >
                  Mapeo
                </button>

                <button
                  type="button"
                  phx-target={@myself}
                  phx-click="map_set_tab"
                  phx-value-tab="preview"
                  class={[
                    "inline-flex items-center justify-center whitespace-nowrap rounded-md border px-3 py-1 text-sm font-medium",
                    @map_view_tab == :preview && "border-stone-300 bg-stone-50 shadow",
                    @map_view_tab != :preview && "border-transparent"
                  ]}
                >
                  Vista previa
                </button>

                <button
                  type="button"
                  phx-target={@myself}
                  phx-click="map_set_tab"
                  phx-value-tab="errors"
                  class={[
                    "inline-flex items-center justify-center whitespace-nowrap rounded-md border px-3 py-1 text-sm font-medium",
                    @map_view_tab == :errors && "border-stone-300 bg-stone-50 shadow",
                    @map_view_tab != :errors && "border-transparent"
                  ]}
                >
                  Errores
                </button>
              </div>
            </div>

            <div class="rounded-md border bg-white">
              <div
                :if={@dry_run_summary && @map_view_tab in [:preview, :errors]}
                class="border-b px-3 py-2 text-xs text-stone-700"
              >
                {@dry_run_summary}
              </div>

              <div class="max-h-96 overflow-auto p-2">
                <div :if={@map_view_tab == :mapping}>
                  <.form
                    :if={@csv_headers != [] and @wizard_step in [:map, :import]}
                    for={to_form(@csv_mapping)}
                    id="csv-mapping-form"
                    phx-target={@myself}
                    phx-submit="csv_validate"
                  >
                    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                      <%= for f <- @config.fields do %>
                        <.input
                          type="select"
                          name={"mapping[#{f.name}]"}
                          label={f.label}
                          options={if f.required, do: @csv_headers, else: ["" | @csv_headers]}
                          value={@csv_mapping[f.name]}
                        />
                      <% end %>
                    </div>
                  </.form>
                </div>

                <div :if={@map_view_tab == :preview}>
                  <table class="min-w-full divide-y divide-stone-200 border">
                    <thead>
                      <tr>
                        <th
                          :for={h <- @csv_headers}
                          class="px-2 py-1 text-left text-xs font-medium text-stone-600"
                        >
                          {h}
                        </th>
                      </tr>
                    </thead>

                    <tbody class="divide-y divide-stone-100">
                      <tr :for={row <- @csv_rows}>
                        <td :for={i <- 0..(length(@csv_headers) - 1)} class="px-2 py-1 text-xs">
                          {Enum.at(row, i)}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <div :if={@map_view_tab == :errors}>
                  <div :if={@csv_errors == []} class="text-sm text-stone-600">Sin errores.</div>

                  <div :if={@csv_errors && @csv_errors != []}>
                    <table class="min-w-full divide-y divide-red-200 border">
                      <thead class="bg-red-50">
                        <tr>
                          <th class="px-2 py-1 text-left text-xs font-medium text-red-700">Fila</th>

                          <th class="px-2 py-1 text-left text-xs font-medium text-red-700">
                            Mensaje
                          </th>
                        </tr>
                      </thead>

                      <tbody class="divide-y divide-red-100">
                        <tr :for={e <- Enum.take(@csv_errors, 25)}>
                          <td class="px-2 py-1 text-xs text-red-800">{e.row}</td>

                          <td class="px-2 py-1 text-xs text-red-800">{e.message}</td>
                        </tr>
                      </tbody>
                    </table>

                    <div :if={length(@csv_errors) > 25} class="mt-1 text-xs text-stone-600">
                      Mostrando los primeros 25 errores de {length(@csv_errors)}.
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <:footer>
          <div class="flex items-center gap-2">
            <.button
              :if={@wizard_step == :provide}
              type="submit"
              id={@id <> "-next"}
              form="csv-select-form"
              disabled={upload_pending?(@csv_upload)}
              variant={:primary}
            >
              Siguiente
            </.button>

            <.button
              :if={@wizard_step == :map and @map_view_tab == :mapping}
              type="submit"
              id={@id <> "-validate"}
              form="csv-mapping-form"
              variant={:primary}
            >
              Verificar
            </.button>

            <.button
              :if={@wizard_step == :map}
              id={@id <> "-next-import"}
              type="button"
              phx-target={@myself}
              phx-click="csv_import_final"
              disabled={@csv_errors && @csv_errors != []}
              variant={:primary}
            >
              Siguiente
            </.button>

            <.button
              :if={@wizard_step == :import}
              id={@id <> "-run-import"}
              type="button"
              phx-target={@myself}
              phx-click="csv_run_import"
              variant={:primary}
            >
              Importar
            </.button>

            <.button variant={:outline} type="button" phx-target={@myself} phx-click="wizard_close">
              Cerrar
            </.button>
          </div>
        </:footer>
      </.modal>
    </div>
    """
  end

  # Events
  @impl true
  def handle_event("wizard_close", _params, socket) do
    send(self(), {:import_modal, :closed})
    {:noreply, socket |> cancel_csv_upload() |> assign(:show, false)}
  end

  @impl true
  def handle_event("csv_clear_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv, ref)}
  end

  # LiveView only starts an upload when the file input (or its form) declares
  # phx-change, so this is what actually kicks off both click-to-pick and
  # drag-and-drop. Typing in the paste box fires the same event, so it must
  # stay a cheap no-op unless a file is actually waiting to be read.
  @impl true
  def handle_event("csv_select_change", params, socket) do
    delimiter = params["delimiter"] || socket.assigns[:csv_delimiter] || ","
    entity = socket.assigns.entity || "products"

    socket = assign(socket, :csv_delimiter, delimiter)

    case consume_uploaded_csv(socket) do
      {:ok, csv_content} ->
        do_csv_preview(entity, csv_content, delimiter, socket)

      {:error, {:rejected, reasons}} ->
        {:noreply,
         socket
         |> cancel_csv_upload()
         |> put_flash(:error, "Archivo rechazado: #{reasons}. Selecciona un archivo CSV válido.")}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("wizard_goto", %{"step" => label}, socket) do
    target = wizard_step_from_label(label)
    current = socket.assigns.wizard_step
    steps = [:provide, :map, :import]
    current_idx = Enum.find_index(steps, &(&1 == current)) || 0
    target_idx = Enum.find_index(steps, &(&1 == target)) || 0

    socket = if target_idx < current_idx, do: assign(socket, :wizard_step, target), else: socket
    {:noreply, socket}
  end

  @impl true
  def handle_event("map_set_tab", %{"tab" => tab}, socket) do
    tab =
      case tab do
        "errors" -> :errors
        "mapping" -> :mapping
        _ -> :preview
      end

    {:noreply, assign(socket, :map_view_tab, tab)}
  end

  @impl true
  def handle_event("csv_import", params, socket) do
    entity = params["entity"] || socket.assigns.entity || "products"
    delimiter = params["delimiter"] || ","
    dry_run? = params["dry_run"] in [true, "true", "on", "1"]
    content = params["csv_content"] || ""

    cond do
      dry_run? and String.trim(content) != "" ->
        do_csv_preview(entity, content, delimiter, socket)

      dry_run? ->
        case consume_uploaded_csv(socket) do
          {:ok, csv_content} ->
            do_csv_preview(entity, csv_content, delimiter, socket)

          {:error, :no_file} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Selecciona un archivo CSV o pega su contenido en el campo de texto."
             )}

          {:error, :uploading} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "El archivo todavía se está subiendo. Espera a que termine e inténtalo de nuevo."
             )}

          {:error, {:rejected, reasons}} ->
            {:noreply,
             socket
             |> cancel_csv_upload()
             |> put_flash(
               :error,
               "Archivo rechazado: #{reasons}. Selecciona un archivo CSV válido."
             )}
        end

      true ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Activa la ejecución de prueba para revisar la vista previa antes de importar."
         )}
    end
  end

  @impl true
  def handle_event("csv_validate", %{"mapping" => mapping_params}, socket) do
    entity = socket.assigns[:csv_entity] || (socket.assigns.entity || "products")
    mapping = normalize_mapping_params(mapping_params)

    case socket.assigns[:csv_preview] do
      nil -> {:noreply, put_flash(socket, :error, "No hay una vista previa de CSV disponible")}
      csv -> do_csv_dry_run(entity, csv, socket.assigns[:csv_delimiter] || ",", mapping, socket)
    end
  end

  @impl true
  def handle_event("csv_import_final", _params, socket) do
    {:noreply, assign(socket, :wizard_step, :import)}
  end

  @impl true
  def handle_event("csv_run_import", _params, socket) do
    entity = socket.assigns[:csv_entity] || (socket.assigns.entity || "products")
    mapping = socket.assigns[:csv_mapping] || %{}
    delimiter = socket.assigns[:csv_delimiter] || ","
    csv = socket.assigns[:csv_preview]

    cfg = entity_config(entity)
    importer = cfg.importer

    cond do
      is_nil(csv) ->
        {:noreply, put_flash(socket, :error, "No hay CSV para importar. Primero ejecuta Verificar.")}

      function_exported?(importer, :import, 2) ->
        actor = socket.assigns[:current_user]

        case importer.import(csv, delimiter: delimiter, mapping: mapping, actor: actor) do
          {:ok, %{inserted: ins, updated: upd, errors: errors}} ->
            msg =
              "Se importaron #{ins + upd} (#{ins} nuevos#{(upd > 0 && ", #{upd} actualizados") || ""})."

            {:noreply,
             socket
             |> assign(:csv_errors, errors)
             |> assign(:dry_run_summary, msg)
             |> assign(:wizard_step, :import)
             |> put_flash(:info, msg)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Error al importar: #{inspect(reason)}")}
        end

      true ->
        {:noreply, put_flash(socket, :error, "La importación no está disponible para #{cfg.label}")}
    end
  end

  # Helpers
  defp wizard_step_from_label(label) do
    case String.downcase(to_string(label)) do
      "cargar csv" -> :provide
      "mapeo" -> :map
      "importar" -> :import
      _ -> :provide
    end
  end

  defp wizard_label(step) do
    case step do
      :provide -> "Cargar CSV"
      :map -> "Mapeo"
      :import -> "Importar"
      _ -> "Cargar CSV"
    end
  end

  defp do_csv_preview(entity, csv, delimiter, socket) do
    headers =
      csv
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false, separator: delimiter)
      |> List.first()

    rows =
      csv
      |> String.trim()
      |> NimbleCSV.RFC4180.parse_string(skip_headers: true, separator: delimiter)
      |> Enum.take(5)

    mapping = default_mapping_for(entity, headers)

    {:noreply,
     socket
     |> assign(:csv_preview, csv)
     |> assign(:csv_headers, headers || [])
     |> assign(:csv_rows, rows)
     |> assign(:csv_mapping, mapping)
     |> assign(:csv_entity, entity)
     |> assign(:csv_delimiter, delimiter)
     |> assign(:wizard_step, :map)
     |> assign(:show, true)}
  end

  defp do_csv_dry_run(entity, csv, delimiter, mapping, socket) do
    cfg = entity_config(entity)
    importer = cfg.importer

    if function_exported?(importer, :dry_run, 2) do
      {:ok, %{rows: rows, errors: errors}} =
        importer.dry_run(csv, delimiter: delimiter, mapping: mapping)

      msg = "Ejecución de prueba: #{length(rows)} filas válidas, #{length(errors)} errores"

      {:noreply,
       socket
       |> assign(:dry_run_summary, msg)
       |> assign(:csv_errors, errors)
       |> assign(:csv_mapping, mapping)
       |> assign(:map_view_tab, if(errors == [], do: :preview, else: :errors))
       |> assign(:wizard_step, :map)}
    else
      {:noreply, put_flash(socket, :error, "La ejecución de prueba no está disponible para #{cfg.label}")}
    end
  end

  defp consume_uploaded_csv(socket) do
    upload = socket.assigns[:uploads][:csv]

    cond do
      upload.entries == [] ->
        {:error, :no_file}

      Enum.any?(upload.entries, &rejected?(&1, upload)) ->
        {:error, {:rejected, rejected_reasons(upload)}}

      Enum.any?(upload.entries, &(not &1.done?)) ->
        {:error, :uploading}

      true ->
        {:ok, read_uploaded_csv(socket)}
    end
  end

  # LiveView only reports upload progress server-side when a :progress callback
  # is registered, otherwise entry.progress stays at 0 forever. This is also
  # the only signal that fires when the transfer finishes, so it is where the
  # wizard moves on to the mapping step by itself.
  defp handle_csv_progress(_name, entry, socket) do
    if entry.done? && socket.assigns.wizard_step == :provide do
      csv = read_uploaded_csv(socket)
      entity = socket.assigns.entity || "products"
      do_csv_preview(entity, csv, socket.assigns[:csv_delimiter] || ",", socket)
    else
      {:noreply, socket}
    end
  end

  defp read_uploaded_csv(socket) do
    [content | _] =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    content
  end

  defp csv_entries(%UploadConfig{} = upload) do
    for entry <- upload.entries do
      %{
        ref: entry.ref,
        client_name: entry.client_name,
        progress: entry.progress,
        status: entry_status(entry, upload)
      }
    end
  end

  defp entry_status(%{done?: true}, _upload), do: {:ready, ""}

  defp entry_status(entry, upload) do
    if rejected?(entry, upload) do
      {:rejected, Enum.join(Phoenix.Component.upload_errors(upload, entry), ", ")}
    else
      {:uploading, ""}
    end
  end

  defp rejected?(%{cancelled?: true}, _upload), do: true

  defp rejected?(%{valid?: false}, _upload), do: true

  defp rejected?(%{done?: true}, _upload), do: false

  defp rejected?(_entry, _upload), do: false

  defp rejected_reasons(%UploadConfig{} = upload) do
    upload.entries
    |> Enum.flat_map(fn entry ->
      case entry_status(entry, upload) do
        {:rejected, ""} -> ["el archivo no cumple los tipos de archivo permitidos"]
        {:rejected, message} -> [message]
        _ -> []
      end
    end)
    |> Enum.uniq()
    |> Enum.join(", ")
  end

  defp upload_pending?(%UploadConfig{} = upload) do
    Enum.any?(upload.entries, &(not &1.done? and not rejected?(&1, upload)))
  end

  defp upload_pending?(_upload), do: false

  defp cancel_csv_upload(socket) do
    Enum.reduce(socket.assigns[:uploads][:csv].entries, socket, fn entry, acc ->
      cancel_upload(acc, :csv, entry.ref)
    end)
  end

  defp default_mapping_for(entity, headers) do
    cfg = entity_config(entity)
    norm = Enum.map(headers || [], &String.downcase(to_string(&1)))

    Enum.reduce(cfg.fields, %{}, fn f, acc ->
      candidates = cfg.default_candidates[f.name] || []
      val = find_header(norm, candidates) || (f.required && nil) || ""
      Map.put(acc, f.name, val)
    end)
  end

  defp find_header(norm_headers, candidates) do
    Enum.find(norm_headers, fn h -> h in candidates end)
  end

  defp normalize_mapping_params(params) do
    Map.new(params, fn {k, v} -> {k, String.downcase(to_string(v || ""))} end)
  end

  # Static per-entity configuration
  defp entity_config(nil), do: entity_config("products")

  defp entity_config(entity) when is_atom(entity), do: entity |> Atom.to_string() |> entity_config()

  defp entity_config("products") do
    %{
      key: "products",
      label: "Productos",
      importer: Craftplan.CSV.Importers.Products,
      instructions: ["Requerido: name, price."],
      fields: [
        %{name: "name", label: "Nombre", required: true},
        %{name: "price", label: "Precio", required: true}
      ],
      default_candidates: %{
        "name" => ["name", "product name"],
        "price" => ["price", "cost", "amount"]
      }
    }
  end

  defp entity_config("materials") do
    %{
      key: "materials",
      label: "Materiales",
      importer: Craftplan.CSV.Importers.Materials,
      instructions: ["Requerido: name, unit. Opcional: color, quantity, extra_description."],
      fields: [
        %{name: "name", label: "Nombre", required: true},
        %{name: "unit", label: "Unidad", required: true},
        %{name: "color", label: "Color", required: false},
        %{name: "quantity", label: "Cantidad", required: false},
        %{name: "extra_description", label: "Descripción", required: false}
      ],
      default_candidates: %{
        "name" => ["name"],
        "unit" => ["unit", "uom", "units"],
        "color" => ["color"],
        "quantity" => ["quantity", "qty", "amount"],
        "extra_description" => ["extra_description", "description", "notes"]
      }
    }
  end

  defp entity_config("customers") do
    %{
      key: "customers",
      label: "Clientes",
      importer: Craftplan.CSV.Importers.Customers,
      instructions: ["Requerido: first_name, last_name, phone, email."],
      fields: [
        %{name: "first_name", label: "Nombre", required: true},
        %{name: "last_name", label: "Apellido", required: true},
        %{name: "phone", label: "Teléfono", required: true},
        %{name: "email", label: "Correo electrónico", required: true}
      ],
      default_candidates: %{
        "first_name" => ["first_name", "firstname", "first name"],
        "last_name" => ["last_name", "lastname", "last name"],
        "phone" => ["phone", "telefono", "telephone", "mobile"],
        "email" => ["email", "email address"]
      }
    }
  end
end
