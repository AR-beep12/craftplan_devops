defmodule CraftplanWeb.AuthOverrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides

  # configure your UI overrides here

  # First argument to `override` is the component name you are overriding.
  # The body contains any number of configurations you wish to override
  # Below are some examples

  # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

  override AshAuthentication.Phoenix.SignInLive do
    set :root_class, "grid h-screen place-items-center dark:bg-stone-50"
  end

  override AshAuthentication.Phoenix.ResetLive do
    set :root_class, "grid h-screen place-items-center dark:bg-stone-50"
  end

  override AshAuthentication.Phoenix.Components.Reset do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24
    """

    set :strategy_class, "mx-auto w-full max-w-sm lg:w-96"
  end

  override AshAuthentication.Phoenix.Components.Reset.Form do
    set :root_class, nil

    set :label_class,
        "mt-2 mb-4 text-2xl tracking-tight font-bold text-stone-900 dark:text-stone-900"

    set :form_class, nil
    set :spacer_class, "py-1"
    set :disable_button_text, "Cambiando contraseña..."
  end

  override AshAuthentication.Phoenix.Components.SignIn do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24 border rounded-md border border-stone-300 bg-stone-200/30
    """

    set :show_banner, false
    set :strategy_class, "mx-auto w-full max-w-sm lg:w-96"

    set :authentication_error_container_class, "text-black dark:text-stone-900 text-center"
    set :authentication_error_text_class, ""
  end

  override AshAuthentication.Phoenix.Components.Banner do
    set :root_class, "w-full flex justify-center py-2"
    set :href_class, nil
    set :href_url, "/"
    set :image_class, "block dark:hidden"
    set :dark_image_class, "hidden dark:block"
    set :image_url, "https://ash-hq.org/images/ash-framework-light.png"
    set :dark_image_url, "https://ash-hq.org/images/ash-framework-dark.png"
    set :text_class, nil
    set :text, nil
  end

  override AshAuthentication.Phoenix.Components.HorizontalRule do
    set :root_class, "relative my-2"
    set :hr_outer_class, "absolute inset-0 flex items-center"
    set :hr_inner_class, "w-full border-t border-stone-300 dark:border-stone-700"
    set :text_outer_class, "relative flex justify-center text-sm"

    set :text_inner_class,
        "px-2 bg-white text-stone-400 font-medium dark:bg-stone-50 dark:text-neutral-900"

    set :text, "o"
  end

  override AshAuthentication.Phoenix.Components.MagicLink do
    set :root_class, "mt-4 mb-4"

    set :label_class,
        "mt-2 mb-4 text-2xl tracking-tight font-bold text-stone-900 dark:text-stone-900"

    set :form_class, nil

    set :request_flash_text,
        "Si este usuario existe en nuestra base de datos, te contactaremos con un enlace de inicio de sesión en breve."

    set :disable_button_text, "Solicitando..."
  end

  override AshAuthentication.Phoenix.Components.Password do
    set :root_class, "mt-4 mb-4"
    set :interstitial_class, "flex flex-row justify-between content-between text-sm font-medium"
    set :toggler_class, "flex-none text-stone-500 hover:text-stone-600 px-2 first:pl-0 last:pr-0"
    set :sign_in_toggle_text, "¿Ya tienes una cuenta?"
    set :register_toggle_text, "¿Necesitas una cuenta?"
    # nil oculta el enlace "¿Olvidaste tu contraseña?" de la pantalla de inicio de sesión
    set :reset_toggle_text, nil
    set :show_first, :sign_in
    set :hide_class, "hidden"
  end

  override AshAuthentication.Phoenix.Components.Password.SignInForm do
    set :root_class, nil

    set :label_class,
        "mt-2 mb-4 text-2xl tracking-tight font-bold text-stone-900 dark:text-stone-900"

    set :form_class, nil
    set :slot_class, "my-4"
    set :disable_button_text, "Iniciando sesión..."
  end

  override AshAuthentication.Phoenix.Components.Password.RegisterForm do
    set :root_class, nil

    set :label_class,
        "mt-2 mb-4 text-2xl tracking-tight font-bold text-stone-900 dark:text-stone-900"

    set :form_class, nil
    set :slot_class, "my-4"
    set :disable_button_text, "Registrando..."
  end

  override AshAuthentication.Phoenix.Components.Password.ResetForm do
    set :root_class, nil

    set :label_class,
        "mt-2 mb-4 text-2xl tracking-tight font-bold text-stone-900 dark:text-stone-900"

    set :form_class, nil
    set :slot_class, "my-4"

    set :reset_flash_text,
        "Si este usuario existe en nuestro sistema, te contactaremos con instrucciones para restablecer tu contraseña en breve."

    set :disable_button_text, "Solicitando..."
  end

  override AshAuthentication.Phoenix.Components.Password.Input do
    set :field_class, "mt-2 mb-2 dark:text-stone-900"
    set :label_class, "block text-sm font-medium text-stone-700 mb-1 dark:text-stone-900"

    set :input_class, """
    appearance-none block w-full px-3 py-2 border border-stone-300 rounded-md
    placeholder-stone-400 focus:outline-none focus:ring-blue-pale-500
    focus:border-blue-pale-500 sm:text-sm dark:text-black
    """

    set :input_class_with_error, """
    appearance-none block w-full px-3 py-2 border border-stone-300 rounded-md
    placeholder-stone-400 focus:outline-none border-red-400 sm:text-sm
    dark:text-black
    """

    set :submit_class, """
    inline-flex w-full items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm
    font-medium focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-stone-300
    disabled:pointer-events-none disabled:opacity-50 border border-stone-300 bg-stone-200/50
    hover:bg-stone-200 hover:text-gray-800 h-9 px-4 py-2
    """

    set :password_input_label, "Contraseña"
    set :password_confirmation_input_label, "Confirmación de contraseña"
    set :identity_input_label, "Correo electrónico"
    set :identity_input_placeholder, nil
    set :error_ul, "text-red-400 font-light my-3 italic text-sm"
    set :error_li, nil
    set :input_debounce, 350
  end

  override AshAuthentication.Phoenix.Components.OAuth2 do
    set :root_class, "w-full mt-2 mb-4"

    set :link_class, """
    w-full flex justify-center py-2 px-4 border border-transparent rounded-md
    text-sm font-medium text-black bg-stone-200 hover:bg-stone-300
    focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
    inline-flex items-center
    """

    set :icon_class, "-ml-0.4 mr-2 h-4 w-4"
  end

  override AshAuthentication.Phoenix.Components.Apple do
    set :root_class, "w-full mt-2 mb-4"

    set :link_class, """
    w-full flex justify-center px-4 border border-transparent rounded-md
    text-sm font-medium text-white bg-black focus:outline-none
    focus:ring-2 focus:ring-offset-2 focus:ring-black inline-flex items-center
    dark:bg-white dark:text-black dark:ring-white
    """

    set :icon_class, ""
  end
end
