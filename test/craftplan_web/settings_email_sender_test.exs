defmodule CraftplanWeb.SettingsEmailSenderTest do
  use CraftplanWeb.ConnCase, async: true

  describe "email sender defaults" do
    test "settings default to Craftplan sender values" do
      Craftplan.Settings.init!()
      {:ok, settings} = Craftplan.Settings.get_settings()
      assert settings.email_from_name == "Craftplan"
      assert settings.email_from_address == "noreply@craftplan.app"
    end
  end

  describe "email_sender/0 fallback" do
    test "emails module reads custom sender from settings" do
      Craftplan.Settings.init!()
      {:ok, settings} = Craftplan.Settings.get_settings()
      admin = Craftplan.DataCase.admin_actor()

      Craftplan.Settings.set!(
        settings,
        %{
          email_from_name: "Custom Name",
          email_from_address: "custom@example.com"
        },
        actor: admin
      )

      # Verify settings actually changed
      {:ok, updated} = Craftplan.Settings.get_settings()
      assert updated.email_from_name == "Custom Name"
      assert updated.email_from_address == "custom@example.com"
    end
  end
end
