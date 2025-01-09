defmodule OrderService.MixProject do
  use Mix.Project

  end

  def project do
    [
      app: :order_service,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {OrderService.Application, []}
    ]
  end

  defp deps do
    [
      {:rabbitmq_client, "~> 0.1.0"},
      {:phoenix, "~> 1.5.9"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end
end
