defmodule FraudDetectorService do


use Genserver


def start_link(_) do
    GenServer.start_link(__MODULE__, :ok , name:__MODULE__)
end

def init(_) do

    # List of RabbitMQ nodes to try connecting to
    amqp_nodes = System.get_env("RABBITMQ_NODES", "rabbitmq,rabbitmq-duplicate-1,rabbitmq-duplicate-2") |> String.split(",")

    IO.puts("Connecting to RabbitMQ nodes: #{inspect(amqp_nodes)}")

    # Try to connect to RabbitMQ nodes with retries
    connection = try_connect(amqp_nodes)
    case connection do
      {:ok, connection} ->
        IO.puts("Connected to RabbitMQ!")
        Process.monitor(connection.pid)

        # Open the channel
        case AMQP.Channel.open(connection) do
          {:ok, channel} ->
            IO.puts("Channel opened!")
            {:ok, %{rabbitmq: {connection, channel}}}

          {:error, reason} ->
            IO.puts("Failed to open channel: #{inspect(reason)}")
            {:stop, :channel_error}
        end

      {:error, reason} ->
        IO.puts("Failed to establish connection with RabbitMQ: #{inspect(reason)}")
        {:stop, :connection_error}
    end

end


defp try_connect([node | rest]) do

    # Get the necessary variables to establish a connection with rabbitmq
    amqp_host = node
    amqp_port = System.get_env("RABBITMQ_PORT", "5672") |> String.to_integer()
    amqp_username = System.get_env("RABBITMQ_USERNAME", "order")
    amqp_password = System.get_env("RABBITMQ_PASSWORD", "order")

    # Attempt a connection
    case AMQP.Connection.open(host: amqp_host, port: amqp_port, username: amqp_username, password: amqp_password) do
      {:ok, connection} ->
        {:ok, connection}

      {:error, reason} ->
        IO.puts("Failed to connect to #{amqp_host}:#{amqp_port} :  #{inspect(reason)}")

        # If there are more nodes, try a different one
        if rest != [] do
          try_connect(rest)
        else
          {:error, reason}
        end
    end
  end

    # Handle received orders
    def handle_info({:basic_deliver, order, _meta}, state) do

      # Acknowledge the message
      AMQP.Basic.ack(state.channel, _meta.delivery_tag)

      {:noreply, state}
    end



end
