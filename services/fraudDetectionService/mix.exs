defmodule FraudDetectionApplication.MixProject do
  use Mix.Project

  def project do
    [
      app: :fraud_detection_application,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: [FraudDetectionApplication]

    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
     {:amqp, "~>3.3"}
    ]
  end
end
