defmodule CraftplanWeb.SettingsMembersLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Ash.Error.Forbidden
  alias Craftplan.Accounts.User

  defp create_staff_member!(email) do
    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      role: :staff,
      password: "TestPassword123!",
      password_confirmation: "TestPassword123!"
    })
    |> Ash.create!(
      context: %{
        strategy: AshAuthentication.Strategy.Password,
        private: %{ash_authentication?: true}
      }
    )
  end

  describe "authorization" do
    @tag role: :staff
    test "staff cannot access members page", %{conn: conn} do
      assert {:error, {:redirect, _}} = live(conn, ~p"/manage/settings/members")
    end

    test "unauthenticated user cannot access members page", %{conn: conn} do
      assert {:error, {:redirect, _}} = live(conn, ~p"/manage/settings/members")
    end

    @tag role: :staff
    test "staff cannot update roles via Ash action", %{user: staff_user} do
      assert {:error, %Forbidden{}} =
               Craftplan.Accounts.update_user_role(staff_user, %{role: :admin}, actor: staff_user)
    end

    @tag role: :staff
    test "staff cannot invite members via Ash action", %{user: staff_user} do
      assert {:error, %Forbidden{}} =
               Craftplan.Accounts.invite_member(
                 %{email: "hack+#{System.unique_integer()}@test.com", role: :admin},
                 actor: staff_user
               )
    end
  end

  describe "index" do
    @tag role: :admin
    test "admin sees Members tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      assert has_element?(view, "header", "Usuarios")
    end

    @tag role: :admin
    test "lists existing members with email and role", %{conn: conn} do
      email = "staff+#{System.unique_integer()}@test.com"
      create_staff_member!(email)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      assert render(view) =~ email
    end

    @tag role: :admin
    test "shows edit and remove buttons for other members", %{conn: conn, user: admin} do
      create_staff_member!("other+#{System.unique_integer()}@test.com")

      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      html = render(view)

      assert html =~ "Editar"
      assert html =~ "Quitar"
      assert html =~ to_string(admin.email)
    end
  end

  describe "invite" do
    @tag role: :admin
    test "opens invite modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      view |> element("button", "Invitar usuario") |> render_click()

      assert has_element?(view, "#invite-member-modal")
      assert has_element?(view, "#invite-member-form")
    end

    @tag role: :admin
    test "invites new staff member and shows in table", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      view |> element("button", "Invitar usuario") |> render_click()

      email = "invited+#{System.unique_integer()}@test.com"

      view
      |> form("#invite-member-form", %{"invite" => %{"email" => email}})
      |> render_change(%{"invite" => %{"email" => email, "role" => "staff"}})

      view
      |> form("#invite-member-form", %{"invite" => %{"email" => email, "role" => "staff"}})
      |> render_submit()

      assert render(view) =~ email
    end
  end

  describe "create user" do
    defp submit_create(view, email, password, confirmation) do
      view |> element("button", "Crear usuario") |> render_click()

      view
      |> form("#create-member-form", %{
        "new_member" => %{
          "email" => email,
          "password" => password,
          "password_confirmation" => confirmation,
          "role" => "staff"
        }
      })
      |> render_submit()
    end

    @tag role: :admin
    test "creates a confirmed user and closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")
      email = "creado+#{System.unique_integer([:positive])}@test.com"

      submit_create(view, email, "Password123!", "Password123!")

      refute has_element?(view, "#create-member-modal")
      assert render(view) =~ email
    end

    @tag role: :admin
    test "the created user is confirmed and can sign in with the given password", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")
      email = "login+#{System.unique_integer([:positive])}@test.com"

      submit_create(view, email, "Password123!", "Password123!")

      assert {:ok, user} =
               User
               |> Ash.Query.for_read(
                 :sign_in_with_password,
                 %{email: email, password: "Password123!"},
                 context: %{private: %{ash_authentication?: true}}
               )
               |> Ash.read_one()

      assert user.role == :staff
      assert user.confirmed_at
    end

    @tag role: :admin
    test "shows an error inside the modal when the email is already registered", %{conn: conn} do
      email = "repetido+#{System.unique_integer([:positive])}@test.com"
      create_staff_member!(email)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")
      submit_create(view, email, "Password123!", "Password123!")

      assert has_element?(view, "#create-member-modal")
      assert has_element?(view, "#create-member-error", "ya está registrado")
    end

    @tag role: :admin
    test "shows an error inside the modal when the passwords do not match", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      submit_create(
        view,
        "x+#{System.unique_integer([:positive])}@test.com",
        "Password123!",
        "Otra12345!"
      )

      assert has_element?(view, "#create-member-modal")
      assert has_element?(view, "#create-member-error", "no coincide")
    end

    @tag role: :admin
    test "shows an error inside the modal when the password is too short", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      submit_create(view, "c+#{System.unique_integer([:positive])}@test.com", "corta", "corta")

      assert has_element?(view, "#create-member-error", "al menos 8")
    end
  end

  describe "update role" do
    @tag role: :admin
    test "opens edit role modal and updates role", %{conn: conn} do
      create_staff_member!("editrole+#{System.unique_integer()}@test.com")

      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      view |> element("button", "Editar") |> render_click()

      assert has_element?(view, "#edit-role-modal")

      view
      |> form("#edit-role-form", %{"role_edit" => %{"role" => "admin"}})
      |> render_change(%{"role_edit" => %{"role" => "admin"}})

      view
      |> form("#edit-role-form", %{"role_edit" => %{"role" => "admin"}})
      |> render_submit()

      # Modal closes after update — verify by checking it's gone
      refute has_element?(view, "#edit-role-modal")
    end
  end

  describe "remove" do
    @tag role: :admin
    test "removes a member from the list", %{conn: conn} do
      email = "remove+#{System.unique_integer()}@test.com"
      create_staff_member!(email)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      assert render(view) =~ email

      view |> element("button", "Quitar") |> render_click()

      refute render(view) =~ email
    end
  end
end
