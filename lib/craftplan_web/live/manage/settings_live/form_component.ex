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
            id="tax-settings"
            aria-labelledby="tax-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="tax-settings-title" class="text-base font-semibold text-stone-800">
                Impuestos y precios
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Elige cómo se aplica el impuesto y define una tasa predeterminada. Las tasas son decimales, por ejemplo, 0.21 para 21%.
              </p>
            </div>
            <div class="grid grid-cols-1 gap-4 p-4 sm:grid-cols-2">
              <.input
                field={@form[:tax_mode]}
                type="select"
                options={[
                  {"Exclusivo (agregar impuesto)", :exclusive},
                  {"Inclusivo (el precio incluye el impuesto)", :inclusive}
                ]}
                label="Modo de impuesto"
              />
              <.input
                field={@form[:tax_rate]}
                type="number"
                step="0.001"
                min="0"
                label="Tasa de impuesto"
                placeholder="0.21"
              />
            </div>
          </section>

          <section
            id="fulfillment-settings"
            aria-labelledby="fulfillment-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="fulfillment-settings-title" class="text-base font-semibold text-stone-800">
                Cumplimiento y capacidad
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Configura cómo se cumplen los pedidos y las reglas de capacidad que orientan la programación.
              </p>
            </div>
            <div class="space-y-6 p-4">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <.input field={@form[:offers_pickup]} type="checkbox" label="Ofrecer recogida" />
                <.input field={@form[:offers_delivery]} type="checkbox" label="Ofrecer entrega" />
                <.input
                  field={@form[:shipping_flat]}
                  type="number"
                  step="0.01"
                  min="0"
                  label="Envío fijo"
                />
              </div>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:lead_time_days]}
                  type="number"
                  min="0"
                  label="Tiempo de espera (días)"
                  placeholder="ej. 2"
                />
                <.input
                  field={@form[:daily_capacity]}
                  type="number"
                  min="0"
                  label="Capacidad diaria"
                  placeholder="0 para ilimitado"
                />
              </div>
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
            id="email-delivery-settings"
            aria-labelledby="email-delivery-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="email-delivery-settings-title" class="text-base font-semibold text-stone-800">
                Entrega de correo
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Elige un proveedor de correo y configura sus credenciales.
              </p>
            </div>
            <div class="space-y-4 p-4">
              <.input
                field={@form[:email_provider]}
                type="select"
                options={provider_options()}
                label="Proveedor"
              />

              <%= case selected_provider(@form) do %>
                <% :smtp -> %>
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.input
                      field={@form[:smtp_host]}
                      type="text"
                      label="Host SMTP"
                      placeholder="smtp.example.com"
                    />
                    <.input
                      field={@form[:smtp_port]}
                      type="number"
                      label="Puerto SMTP"
                      placeholder="587"
                    />
                  </div>
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.input
                      field={@form[:smtp_username]}
                      type="text"
                      label="Usuario"
                      placeholder="user@example.com"
                    />
                    <.input
                      field={@form[:smtp_password]}
                      type="password"
                      label="Contraseña"
                      placeholder="••••••••"
                    />
                  </div>
                  <.input
                    field={@form[:smtp_tls]}
                    type="select"
                    options={[
                      {"Si está disponible", :if_available},
                      {"Siempre", :always},
                      {"Nunca", :never}
                    ]}
                    label="Modo TLS"
                  />
                <% provider when provider in [:sendgrid, :postmark, :brevo] -> %>
                  <.input
                    field={@form[:email_api_key]}
                    type="password"
                    label="Clave API"
                    placeholder="••••••••"
                  />
                <% :mailgun -> %>
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.input
                      field={@form[:email_api_key]}
                      type="password"
                      label="Clave API"
                      placeholder="••••••••"
                    />
                    <.input
                      field={@form[:email_api_domain]}
                      type="text"
                      label="Dominio"
                      placeholder="mg.example.com"
                    />
                  </div>
                <% :amazon_ses -> %>
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.input
                      field={@form[:email_api_key]}
                      type="password"
                      label="Clave de acceso"
                      placeholder="AKIA..."
                    />
                    <.input
                      field={@form[:email_api_secret]}
                      type="password"
                      label="Clave secreta"
                      placeholder="••••••••"
                    />
                  </div>
                  <.input
                    field={@form[:email_api_region]}
                    type="select"
                    options={ses_region_options()}
                    label="Región"
                  />
                <% _ -> %>
              <% end %>
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

  defp selected_provider(form) do
    value = Phoenix.HTML.Form.input_value(form, :email_provider)

    case value do
      v when is_atom(v) and not is_nil(v) -> v
      v when is_binary(v) and v != "" -> String.to_existing_atom(v)
      _ -> :smtp
    end
  end

  defp provider_options do
    [
      {"SMTP", :smtp},
      {"SendGrid", :sendgrid},
      {"Mailgun", :mailgun},
      {"Postmark", :postmark},
      {"Brevo (Sendinblue)", :brevo},
      {"Amazon SES", :amazon_ses}
    ]
  end

  defp ses_region_options do
    [
      {"EE. UU. Este (Norte de Virginia)", "us-east-1"},
      {"EE. UU. Oeste (Oregón)", "us-west-2"},
      {"UE (Irlanda)", "eu-west-1"},
      {"UE (Fráncfort)", "eu-central-1"},
      {"Asia-Pacífico (Bombay)", "ap-south-1"},
      {"Asia-Pacífico (Sídney)", "ap-southeast-2"}
    ]
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
