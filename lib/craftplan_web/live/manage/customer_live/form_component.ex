defmodule CraftplanWeb.CustomerLive.FormComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="customer-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="mt-4 space-y-8 bg-white">
          <div class="space-y-4">
            <div class="flex flex-row space-x-4">
              <.input field={@form[:first_name]} type="text" label="Nombre" />
              <.input field={@form[:last_name]} type="text" label="Apellido" />
            </div>
            <.input field={@form[:email]} type="email" label="Correo electrónico" />
            <.input field={@form[:phone]} type="tel" label="Teléfono" />
          </div>
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Guardando...">Guardar cliente</.button>
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
  def handle_event("validate", %{"customer" => customer_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, customer_params))}
  end

  def handle_event("save", %{"customer" => customer_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: customer_params) do
      {:ok, customer} ->
        notify_parent({:saved, customer})

        verb = if socket.assigns.form.source.type == :create, do: "creado", else: "actualizado"

        {:noreply,
         socket
         |> put_flash(:info, "Cliente #{verb} correctamente")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{customer: customer}} = socket) do
    form =
      if customer do
        AshPhoenix.Form.for_update(customer, :update,
          as: "customer",
          actor: socket.assigns.current_user
        )
      else
        AshPhoenix.Form.for_create(Craftplan.CRM.Customer, :create,
          as: "customer",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end
end
