defmodule OrderService.MixProject do
  use Mix.Project


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
      applications: [:amqp],
      extra_applications: [:logger, :public_key],
      mod: {OrderService.Application, []}
    ]
  end

  defp deps do
    [
      {:amqp, "~> 3.3"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end


end
