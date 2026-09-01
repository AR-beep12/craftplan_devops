defmodule CraftplanWeb.AuthController do
  use CraftplanWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/manage/dashboard"

    message =
      case activity do
        {:confirm_new_user, :confirm} -> "Tu dirección de correo electrónico ha sido confirmada"
        {:password, :reset} -> "Tu contraseña se ha restablecido correctamente"
        _ -> "Has iniciado sesión"
      end

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    # If your resource has a different name, update the assign name here (i.e :current_admin)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {{:magic_link, _},
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          Ya has iniciado sesión de otra forma, pero no has confirmado tu cuenta.
          Puedes confirmar tu cuenta usando el enlace que te enviamos, o restableciendo tu contraseña.
          """

        _ ->
          "Correo electrónico o contraseña incorrectos"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:craftplan)
    |> put_flash(:info, "Has cerrado sesión")
    |> redirect(to: return_to)
  end
end
