defmodule CraftplanWeb.SettingsLive.MembersComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias Craftplan.Accounts

  require Logger

  @role_colors [
    admin: "bg-purple-100 text-purple-700 border-purple-300",
    staff: "bg-blue-100 text-blue-700 border-blue-300",
    customer: "bg-stone-100 text-stone-700 border-stone-300"
  ]

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:show_invite_modal, fn -> false end)
      |> assign_new(:show_create_modal, fn -> false end)
      |> assign_new(:create_error, fn -> nil end)
      |> assign_new(:show_edit_modal, fn -> false end)
      |> assign_new(:editing_member, fn -> nil end)

    ~H"""
    <div class="space-y-6">
      <.header>
        <:subtitle>
          Gestiona los usuarios del equipo y sus roles de acceso.
        </:subtitle>
        Usuarios
        <:actions>
          <div class="flex flex-wrap items-center gap-3">
            <.button
              type="button"
              variant={:secondary}
              phx-click="show_create_modal"
              phx-target={@myself}
            >
              <.icon name="hero-user-plus" class="mr-2 -ml-1 h-4 w-4" /> Crear usuario
            </.button>

            <.button
              type="button"
              variant={:primary}
              phx-click="show_invite_modal"
              phx-target={@myself}
            >
              <.icon name="hero-plus" class="mr-2 -ml-1 h-4 w-4" /> Invitar usuario
            </.button>
          </div>
        </:actions>
      </.header>

      <div class="rounded-md border border-gray-200 bg-white">
        <div class="p-4">
          <.table id="members" rows={@members} wrapper_class="mt-0">
            <:col :let={member} label="Correo electrónico">{member.email}</:col>

            <:col :let={member} label="Rol">
              <.badge text={role_label(member.role)} colors={role_colors()} />
            </:col>

            <:col :let={member} label="Estado">
              <span
                :if={member.confirmed_at}
                class="ring-green-600/20 inline-flex items-center rounded-full bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset"
              >
                Activo
              </span>

              <span
                :if={is_nil(member.confirmed_at)}
                class="ring-yellow-600/20 inline-flex items-center rounded-full bg-yellow-50 px-2 py-1 text-xs font-medium text-yellow-700 ring-1 ring-inset"
              >
                Pendiente
              </span>
            </:col>

            <:col :let={member} label="Se unió">
              {if Map.get(member, :confirmed_at),
                do: Calendar.strftime(member.confirmed_at, "%Y-%m-%d"),
                else: "—"}
            </:col>

            <:action :let={member}>
              <.button
                :if={member.id != @current_user.id}
                size={:sm}
                variant={:secondary}
                phx-click={JS.push("show_edit_modal", value: %{id: member.id}, target: @myself)}
              >
                Editar
              </.button>

              <.button
                :if={member.id != @current_user.id}
                size={:sm}
                variant={:danger}
                phx-click={JS.push("remove_member", value: %{id: member.id}, target: @myself)}
                data-confirm="¿Estás seguro de que deseas quitar a este miembro? Esta acción no se puede deshacer."
              >
                Quitar
              </.button>
            </:action>

            <:empty>
              <div class="py-6 text-center text-sm text-stone-500">
                Aún no hay miembros del equipo. Invita a uno usando el botón de arriba.
              </div>
            </:empty>
          </.table>
        </div>
      </div>

      <.modal
        :if={@show_invite_modal}
        id="invite-member-modal"
        show
        title="Invitar miembro"
        description="Envía una invitación a un nuevo miembro del equipo"
        on_cancel={JS.push("hide_invite_modal", target: @myself)}
      >
        <.simple_form
          for={@invite_form}
          id="invite-member-form"
          phx-target={@myself}
          phx-change="validate_invite"
          phx-submit="invite_member"
        >
          <.input
            field={@invite_form[:email]}
            type="email"
            label="Correo electrónico"
            placeholder="member@example.com"
          />
          <.input
            field={@invite_form[:role]}
            type="radiogroup"
            label="Rol"
            options={[{"Personal", :staff}, {"Administrador", :admin}]}
            value={@invite_form[:role].value || :staff}
          />
          <:actions>
            <.button variant={:primary} phx-disable-with="Enviando...">Enviar invitación</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <.modal
        :if={@show_create_modal}
        id="create-member-modal"
        show
        title="Crear usuario"
        description="Crea una cuenta directamente con correo y contraseña. No se envía ningún correo."
        on_cancel={JS.push("hide_create_modal", target: @myself)}
      >
        <.simple_form
          for={@create_form}
          id="create-member-form"
          phx-target={@myself}
          phx-change="validate_create"
          phx-submit="create_member"
        >
          <div
            :if={@create_error}
            id="create-member-error"
            role="alert"
            class="rounded-md border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
          >
            {@create_error}
          </div>

          <.input
            field={@create_form[:email]}
            type="email"
            label="Correo electrónico"
            placeholder="member@example.com"
          />
          <.input
            field={@create_form[:password]}
            type="password"
            label="Contraseña"
            placeholder="Mínimo 8 caracteres"
          />
          <.input
            field={@create_form[:password_confirmation]}
            type="password"
            label="Confirmar contraseña"
          />
          <.input
            field={@create_form[:role]}
            type="radiogroup"
            label="Rol"
            options={[{"Personal", :staff}, {"Administrador", :admin}]}
            value={@create_form[:role].value || :staff}
          />
          <:actions>
            <.button variant={:primary} phx-disable-with="Creando...">Crear usuario</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <.modal
        :if={@show_edit_modal}
        id="edit-role-modal"
        show
        title="Editar rol"
        description={"Cambiar rol de #{@editing_member && @editing_member.email}"}
        on_cancel={JS.push("hide_edit_modal", target: @myself)}
      >
        <.simple_form
          for={@role_form}
          id="edit-role-form"
          phx-target={@myself}
          phx-change="validate_role"
          phx-submit="update_role"
        >
          <.input
            field={@role_form[:role]}
            type="radiogroup"
            label="Rol"
            options={[{"Personal", :staff}, {"Administrador", :admin}]}
            value={@role_form[:role].value}
          />
          <:actions>
            <.button variant={:primary} phx-disable-with="Actualizando...">Actualizar rol</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    members = load_members(assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:members, members)
     |> assign(:show_invite_modal, false)
     |> assign(:show_create_modal, false)
     |> assign(:show_edit_modal, false)
     |> assign(:editing_member, nil)
     |> assign(:invite_form, invite_form())
     |> assign(:create_form, create_form())
     |> assign(:create_error, nil)
     |> assign(:role_form, role_form(:staff))}
  end

  @impl true
  def handle_event("show_invite_modal", _, socket) do
    {:noreply, assign(socket, :show_invite_modal, true)}
  end

  @impl true
  def handle_event("hide_invite_modal", _, socket) do
    {:noreply, assign(socket, show_invite_modal: false, invite_form: invite_form())}
  end

  @impl true
  def handle_event("show_create_modal", _, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  @impl true
  def handle_event("hide_create_modal", _, socket) do
    {:noreply, assign(socket, show_create_modal: false, create_form: create_form(), create_error: nil)}
  end

  @impl true
  def handle_event("show_edit_modal", %{"id" => id}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:show_edit_modal, true)
     |> assign(:editing_member, member)
     |> assign(:role_form, role_form(member.role))}
  end

  @impl true
  def handle_event("hide_edit_modal", _, socket) do
    {:noreply, assign(socket, show_edit_modal: false, editing_member: nil)}
  end

  @impl true
  def handle_event("validate_invite", %{"invite" => params}, socket) do
    {:noreply, assign(socket, :invite_form, invite_form(params))}
  end

  @impl true
  def handle_event("validate_role", %{"role_edit" => params}, socket) do
    {:noreply, assign(socket, :role_form, role_form(params["role"]))}
  end

  @impl true
  def handle_event("validate_create", %{"new_member" => params}, socket) do
    {:noreply, socket |> assign(:create_form, create_form(params)) |> assign(:create_error, nil)}
  end

  @impl true
  def handle_event("invite_member", %{"invite" => params}, socket) do
    invite_params = %{
      email: params["email"],
      role: params["role"] || "staff"
    }

    case Accounts.invite_member(invite_params, actor: socket.assigns.current_user) do
      {:ok, _user} ->
        members = load_members(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign(:show_invite_modal, false)
         |> assign(:invite_form, invite_form())
         |> put_flash(:info, "Miembro invitado correctamente")}

      {:error, _error} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "No se pudo invitar al miembro. Es posible que el correo ya esté en uso."
         )}
    end
  end

  @impl true
  def handle_event("create_member", %{"new_member" => params}, socket) do
    create_params = %{
      email: params["email"],
      role: params["role"] || "staff",
      password: params["password"],
      password_confirmation: params["password_confirmation"]
    }

    case Accounts.create_member(create_params, actor: socket.assigns.current_user) do
      {:ok, _user} ->
        members = load_members(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign(:show_create_modal, false)
         |> assign(:create_form, create_form())
         |> assign(:create_error, nil)
         |> put_flash(:info, "Usuario creado correctamente")}

      {:error, error} ->
        Logger.error("create_member failed: " <> String.slice(Exception.message(error), 0, 500))

        {:noreply,
         socket
         |> assign(:create_form, create_form(params))
         |> assign(:create_error, create_error_message(error))}
    end
  end

  @impl true
  def handle_event("update_role", %{"role_edit" => params}, socket) do
    member = socket.assigns.editing_member

    case Accounts.update_user_role(member, %{role: params["role"]}, actor: socket.assigns.current_user) do
      {:ok, _updated} ->
        members = load_members(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign(:show_edit_modal, false)
         |> assign(:editing_member, nil)
         |> put_flash(:info, "Rol actualizado correctamente")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "No se pudo actualizar el rol.")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"id" => id}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.id == id))

    case Accounts.remove_member(member, actor: socket.assigns.current_user) do
      :ok ->
        members = load_members(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:members, members)
         |> put_flash(:info, "Miembro eliminado correctamente")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "No se pudo quitar al miembro.")}
    end
  end

  defp load_members(user) do
    Accounts.list_members!(actor: user)
  end

  defp invite_form(params \\ %{}) do
    to_form(Map.merge(%{"email" => "", "role" => "staff"}, params), as: "invite")
  end

  defp create_form(params \\ %{}) do
    to_form(
      Map.merge(
        %{"email" => "", "password" => "", "password_confirmation" => "", "role" => "staff"},
        params
      ),
      as: "new_member"
    )
  end

  defp create_error_message(%Ash.Error.Invalid{errors: errors}) do
    case errors |> Enum.map(&format_create_error/1) |> Enum.uniq() do
      [] -> "No se pudo crear el usuario."
      messages -> Enum.join(messages, " ")
    end
  end

  defp create_error_message(_error), do: "No se pudo crear el usuario. Inténtalo de nuevo."

  defp format_create_error(%{field: field, message: message}) when not is_nil(field) and is_binary(message) do
    "#{field_label(field)} #{translate_error(message)}."
  end

  defp format_create_error(error), do: Exception.message(error)

  defp field_label(:email), do: "El correo"
  defp field_label(:password), do: "La contraseña"
  defp field_label(:password_confirmation), do: "La confirmación de contraseña"
  defp field_label(field), do: "El campo #{field}"

  defp translate_error("has already been taken"), do: "ya está registrado"
  defp translate_error("does not match"), do: "no coincide con la contraseña"
  defp translate_error("is required"), do: "es obligatorio"
  defp translate_error("is invalid"), do: "no es válido"

  defp translate_error(message) do
    if String.contains?(message, "greater than or equal to"),
      do: "debe tener al menos 8 caracteres",
      else: message
  end

  defp role_form(role) do
    to_form(%{"role" => to_string(role)}, as: "role_edit")
  end

  defp role_colors, do: @role_colors

  defp role_label(:admin), do: "Administrador"
  defp role_label(:staff), do: "Personal"
  defp role_label(:customer), do: "Cliente"

  defp role_label(role) when is_binary(role), do: role |> String.to_existing_atom() |> role_label()

  defp role_label(role), do: to_string(role)
end
