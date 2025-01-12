defmodule FraudDetectionApplication do

  use Application


  def start(_type, _args) do
    children = [
      OrderCreator
    ]

    opts = [strategy: :one_for_one, name: OrderService.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
