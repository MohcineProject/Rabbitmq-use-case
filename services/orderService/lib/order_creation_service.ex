defmodule OrderCreator do
  use GenServer

  @interval 10000
  @queue_name "orders"
  @customers %{
    "John" => ["strawberries", "watermelon", "bananas"],
    "Alice" => ["smartphone", "laptop", "headphones"],
    "Mike" => ["carrots", "broccoli", "spinach"],
    "Sarah" => ["coffee", "tea", "orange juice"],
    "Emma" => ["novel", "self-help book", "cookbook"]
  }

  def start_link(_) do
    # Start the GenServer
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    # Get the host and port of the RabbitMQ microservice
    amqp_host = System.get_env("RABBITMQ_HOST", "rabbitmq")
    amqp_port = System.get_env("RABBITMQ_PORT", "5672") |> String.to_integer()
    amqp_username = System.get_env("RABBITMQ_USERNAME", "order")
    amqp_password = System.get_env("RABBITMQ_PASSWORD", "order")

    IO.puts("Connecting to RabbitMQ on #{amqp_host}:#{amqp_port}")

    # Attempt to connect to RabbitMQ
    case AMQP.Connection.open(
           host: amqp_host,
           port: amqp_port,
           username: amqp_username,
           password: amqp_password
         ) do
      {:ok, connection} ->
        IO.puts("Yes, I am connected!")
        Process.monitor(connection.pid)

        case AMQP.Channel.open(connection) do
          {:ok, channel} ->
            IO.puts("Yes, I have a channel!")
            AMQP.Queue.declare(channel, @queue_name)

            # Schedule the first order
            Process.send(self(), :send_order, [])

            # Return the state of the GenServer
            {:ok, %{rabbitmq: {connection, channel}}}

          {:error, reason} ->
            IO.puts("Failed to start the channel: #{inspect reason}")
            {:stop, :channel_error}
        end

      {:error, reason} ->
        IO.puts("Failed to establish connection with RabbitMQ: #{inspect reason}")
        {:stop, :connection_error}
    end
  end

  # Sends an order to the RabbitMQ queue at each interval
  def handle_info(:send_order, %{rabbitmq: {_connection, channel}} = state) do
    try do
      # Select a random customer and product
      customer_names = Map.keys(@customers)
      random_customer = Enum.random(customer_names)
      selected_product = Enum.random(@customers[random_customer])
      IO.puts("The created order is : #{random_customer} ordered #{selected_product}")

      # Publish the order to the RabbitMQ queue
      IO.puts("Attempting to send order: #{random_customer} ordered #{selected_product}")

      case AMQP.Basic.publish(channel, "", @queue_name, "#{random_customer} ordered #{selected_product}") do
        :ok ->
          IO.puts("Successfully published message")
          error ->
          IO.puts("Failed to publish message: #{inspect(error)}")
          end

      # Schedule the next order
      Process.send_after(self(), :send_order, @interval)

      # Return the response of the call
      {:noreply, state}
    rescue
      e ->
        IO.puts("Error during send_order: #{inspect(e)}")
        {:stop, :error, state}
    end
  end

  # Handle RabbitMQ connection/channel closure
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    IO.puts("RabbitMQ connection/channel lost: #{inspect(reason)}")
    {:stop, :connection_lost, state}
  end
end
