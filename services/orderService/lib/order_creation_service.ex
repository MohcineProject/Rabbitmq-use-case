defmodule OrderCreator do
  use GenServer

  @interval 5000
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
            AMQP.Queue.declare(channel, @queue_name, durable: true, arguments: [
              {"x-queue-type", :longstr, "quorum"}
            ])



            # Schedule the first order
            Process.send(self(), :send_order, [])

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

  def handle_info(:send_order, %{rabbitmq: {_connection, channel}} = state) do
    try do
      # Select a random customer and product
      customer_names = Map.keys(@customers)
      random_customer = Enum.random(customer_names)
      selected_product = Enum.random(@customers[random_customer])
      IO.puts("The created order is : #{random_customer} ordered #{selected_product}")

      # Publish the order to the RabbitMQ queue
      IO.puts("Attempting to send order: #{random_customer} ordered #{selected_product}")

      case AMQP.Basic.publish(channel, "", @queue_name, "#{random_customer} ordered #{selected_product}" , persistent: true) do
        :ok ->
          IO.puts("Successfully published message")
        error ->
          IO.puts("Failed to publish message: #{inspect(error)}")
      end

      # Schedule the next order
      Process.send_after(self(), :send_order, @interval)

      {:noreply, state}
    rescue
      e ->
        IO.puts("Error during send_order: #{inspect(e)}")
        {:stop, :error, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    IO.puts("RabbitMQ connection/channel lost: #{inspect(reason)}")

    # Retry connecting to RabbitMQ nodes
    amqp_nodes = System.get_env("RABBITMQ_NODES", "rabbitmq,rabbitmq-duplicate-1,rabbitmq-duplicate-2") |> String.split(",")
    connection = try_connect(amqp_nodes)

    case connection do
      {:ok, connection} ->
        IO.puts("Reconnected to RabbitMQ !")
        Process.monitor(connection.pid)

        case AMQP.Channel.open(connection) do
          {:ok, channel} ->
            IO.puts("New channel opened ! ")

            {:noreply, %{state | rabbitmq: {connection, channel}}}
            {:error, reason} ->
              IO.puts("Failed to open channel after reconnect: #{inspect(reason)}")
              {:stop, :channel_error}

        end

      {:error, reason} ->
        IO.puts("Failed to reconnect to RabbitMQ: #{inspect(reason)}")
        {:stop, :reconnection_failed}
    end
  end
end
