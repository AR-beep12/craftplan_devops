defmodule CraftplanWeb.SetupLive do
  @moduledoc false
  use CraftplanWeb, :live_view_blank

  alias Craftplan.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    if admin_exists?() do
      {:ok,
       socket
       |> put_flash(:info, "La configuración inicial ya se completó.")
       |> redirect(to: ~p"/sign-in")}
    else
      form =
        AshPhoenix.Form.for_create(User, :register_with_password,
          as: "user",
          authorize?: false
        )

      {:ok,
       socket
       |> assign(:page_title, "Configuración inicial")
       |> assign(:form, to_form(form))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto flex min-h-screen items-center justify-center bg-stone-50 px-4">
      <div class="w-full max-w-md space-y-6">
        <div class="text-center">
          <h1 class="text-2xl font-bold text-stone-900">Bienvenido a Craftplan</h1>

          <p class="mt-2 text-sm text-stone-600">
            Crea tu cuenta de administrador para comenzar.
          </p>
        </div>

        <div class="rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
          <.simple_form
            for={@form}
            id="setup-form"
            phx-change="validate"
            phx-submit="setup"
          >
            <.input field={@form[:email]} type="email" label="Correo electrónico" />
            <.input field={@form[:password]} type="password" label="Contraseña" />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirmar contraseña"
            />
            <:actions>
              <.button variant={:primary} phx-disable-with="Creando cuenta..." class="w-full">
                Crear cuenta de administrador
              </.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("setup", %{"user" => user_params}, socket) do
    if admin_exists?() do
      {:noreply,
       socket
       |> put_flash(:error, "La configuración inicial ya se completó.")
       |> redirect(to: ~p"/sign-in")}
    else
      user_params = Map.put(user_params, "role", "admin")

      case AshPhoenix.Form.submit(socket.assigns.form, params: user_params, authorize?: false) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Cuenta de administrador creada. Por favor, inicia sesión.")
           |> redirect(to: ~p"/sign-in")}

        {:error, form} ->
          {:noreply, assign(socket, form: to_form(form))}
      end
    end
  end

  defp admin_exists? do
    [authorize?: false]
    |> Craftplan.Accounts.list_admin_users!()
    |> Enum.any?()
  end
end
