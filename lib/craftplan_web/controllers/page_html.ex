defmodule CraftplanWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use CraftplanWeb, :html

  embed_templates "page_html/*"

  defp landing_modules do
    [
      %{
        icon: "hero-shopping-bag-solid",
        label: "Pedidos",
        description: "Registrá y seguí cada pedido de tus clientas."
      },
      %{
        icon: "hero-archive-box-solid",
        label: "Inventario",
        description: "Controlá lo que tenés disponible en todo momento."
      },
      %{
        icon: "hero-squares-2x2-solid",
        label: "Producción",
        description: "Organizá qué se hace y cuándo se entrega."
      },
      %{
        icon: "hero-user-group-solid",
        label: "Clientes",
        description: "Toda la información de a quién le vendés."
      }
    ]
  end
end
