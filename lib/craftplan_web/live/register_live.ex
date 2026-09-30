defmodule CraftplanWeb.RegisterLive do
  @moduledoc false
  use CraftplanWeb, :live_view_blank

  alias Craftplan.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_create(User, :register_with_password,
        as: "user",
        authorize?: false
      )

    {:ok,
     socket
     |> assign(:page_title, "Crear cuenta")
     |> assign(:form, to_form(form))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto flex min-h-screen items-center justify-center bg-stone-50 px-4">
      <div class="w-full max-w-md space-y-6">
        <div class="text-center">
          <h1 class="text-2xl font-bold text-stone-900">Crear cuenta</h1>

          <p class="mt-2 text-sm text-stone-600">
            Regístrate para comenzar a usar Craftplan.
          </p>
        </div>

        <div class="rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
          <.simple_form
            for={@form}
            id="register-form"
            phx-change="validate"
            phx-submit="register"
          >
            <.input field={@form[:name]} type="text" label="Nombre" placeholder="Tu nombre" />
            <.input field={@form[:email]} type="email" label="Correo electrónico" />
            <.input field={@form[:password]} type="password" label="Contraseña" />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirmar contraseña"
            />
            <:actions>
              <.button variant={:primary} phx-disable-with="Registrando..." class="w-full">
                Crear cuenta
              </.button>
            </:actions>
          </.simple_form>
        </div>

        <p class="text-center text-sm text-stone-600">
          ¿Ya tienes cuenta?
          <.link navigate={~p"/sign-in"} class="text-primary-600 font-medium hover:text-primary-500">
            Inicia sesión
          </.link>
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("register", %{"user" => user_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: user_params, authorize?: false) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cuenta creada correctamente. Por favor, inicia sesión.")
         |> redirect(to: ~p"/sign-in")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end
end
