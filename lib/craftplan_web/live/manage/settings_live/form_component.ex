defmodule CraftplanWeb.SettingsLive.FormComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="settings-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-8">
          <section
            id="general-settings"
            aria-labelledby="general-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="general-settings-title" class="text-base font-semibold text-stone-800">
                General
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Define la moneda predeterminada utilizada en pedidos, facturas e informes.
              </p>
            </div>
            <div class="space-y-4 p-4">
              <.input
                field={@form[:currency]}
                type="select"
                options={currency_options()}
                label="Moneda predeterminada"
              />
            </div>
          </section>

          <section
            id="email-sender-settings"
            aria-labelledby="email-sender-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="email-sender-settings-title" class="text-base font-semibold text-stone-800">
                Remitente de correo
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Configura el nombre y la dirección del remitente utilizados para los correos salientes.
              </p>
            </div>
            <div class="grid grid-cols-1 gap-4 p-4 sm:grid-cols-2">
              <.input
                field={@form[:email_from_name]}
                type="text"
                label="Nombre del remitente"
                placeholder="Craftplan"
              />
              <.input
                field={@form[:email_from_address]}
                type="email"
                label="Correo del remitente"
                placeholder="noreply@craftplan.app"
              />
            </div>
          </section>

          <section
            id="forecasting-settings"
            aria-labelledby="forecasting-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="forecasting-settings-title" class="text-base font-semibold text-stone-800">
                Pronóstico de inventario
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Ajusta cómo el planificador de reabastecimiento calcula el stock de seguridad, los puntos de reorden y las cantidades sugeridas.
              </p>
            </div>
            <div class="space-y-6 p-4">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <.input
                  field={@form[:forecast_lookback_days]}
                  type="number"
                  min="7"
                  max="365"
                  label="Días de historial"
                  placeholder="42"
                />
                <.input
                  field={@form[:forecast_default_horizon_days]}
                  type="number"
                  min="7"
                  max="90"
                  label="Horizonte predeterminado (días)"
                  placeholder="14"
                />
                <.input
                  field={@form[:forecast_min_samples]}
                  type="number"
                  min="3"
                  max="100"
                  label="Muestras mínimas para variabilidad"
                  placeholder="10"
                />
              </div>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <.input
                  field={@form[:forecast_actual_weight]}
                  type="number"
                  step="0.01"
                  min="0"
                  max="1"
                  label="Peso del uso real"
                  placeholder="0.6"
                />
                <.input
                  field={@form[:forecast_planned_weight]}
                  type="number"
                  step="0.01"
                  min="0"
                  max="1"
                  label="Peso del uso planificado"
                  placeholder="0.4"
                />
                <.input
                  field={@form[:forecast_default_service_level]}
                  type="number"
                  step="0.01"
                  min="0.8"
                  max="0.999"
                  label="Nivel de servicio predeterminado"
                  placeholder="0.95"
                />
              </div>
              <p class="text-xs text-stone-500">
                Los pesos real y planificado deben sumar 1. Niveles de servicio más altos aumentan el stock de seguridad.
              </p>
            </div>
          </section>
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Guardando...">Guardar configuración</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"settings" => setting_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, setting_params))}
  end

  def handle_event("save", %{"settings" => setting_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: setting_params) do
      {:ok, settings} ->
        Craftplan.Mailer.apply_settings(settings)
        notify_parent({:saved, settings})

        {:noreply,
         socket
         |> put_flash(:info, "Configuración actualizada correctamente")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{settings: settings}} = socket) do
    form =
      AshPhoenix.Form.for_update(settings, :update,
        as: "settings",
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end

  @priority_currencies [:USD, :EUR]

  defp currency_options do
    priority_options = Enum.map(@priority_currencies, &{currency_display_name(&1), &1})

    rest_options =
      Craftplan.Types.Currency.values()
      |> Enum.reject(&(&1 in @priority_currencies))
      |> Enum.map(&{currency_display_name(&1), &1})
      |> Enum.reject(fn {name, _code} -> is_nil(name) end)
      |> Enum.sort_by(fn {name, _code} -> name end)

    priority_options ++ rest_options
  end

  defp currency_display_name(code) do
    code
    |> Cldr.Currency.display_name!(backend: Craftplan.Cldr, locale: "es")
    |> capitalize_first()
  rescue
    _ -> code |> to_string() |> String.upcase()
  end

  # Capitalizes only the first grapheme, since CLDR names may contain
  # proper nouns mid-string (e.g. "dólar del Caribe Oriental") that
  # String.capitalize/1 would incorrectly lowercase.
  defp capitalize_first(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest
  defp capitalize_first(other), do: other
end
