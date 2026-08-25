defmodule Craftplan.Cldr do
  @moduledoc false
  use Cldr,
    otp_app: :craftplan,
    locales: ["en", "es"],
    default_locale: "en",
    json_library: Jason,
    providers: [Cldr.Number, Cldr.Currency],
    precompile_number_formats: ["¤¤#,##0.##"]
end
