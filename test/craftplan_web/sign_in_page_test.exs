defmodule CraftplanWeb.SignInPageTest do
  use CraftplanWeb.ConnCase, async: true

  test "la pantalla de inicio de sesión no ofrece recuperar la contraseña", %{conn: conn} do
    html = conn |> get(~p"/sign-in") |> html_response(200)

    assert html =~ "Contraseña"
    refute html =~ "Olvidaste"
    refute html =~ "Forgot your password"
    refute html =~ "Restablecer contraseña"
  end
end
