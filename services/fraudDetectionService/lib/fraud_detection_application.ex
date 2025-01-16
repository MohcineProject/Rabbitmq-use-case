defmodule FraudDetectionApplication do

  use Application


  def start(_type, _args) do
    children = [
      FraudDetectorService
    ]

    opts = [strategy: :one_for_one, name: FraudDetectorService.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
