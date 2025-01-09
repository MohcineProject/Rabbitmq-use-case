defmodule OrderCreator do
  use GenServer

  @interval 2000
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
    # Connect to RabbitMQ
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)

    # Declare the queue "orders"
    AMQP.Queue.declare(channel, @queue_name)

    # Schedule the first order
    Process.send(self(), :send_order, [])

    {:ok, %{rabbitmq: {connection, channel}}}
  end

  # Sends an order to the RabbitMQ queue
  def handle_info(:send_order, %{rabbitmq: {_connection, channel}} = state) do
    # Selecting a random customer
    customer_names = Map.keys(@customers)
    random_customer = Enum.random(customer_names)

    # Selecting a random product from the customer's list
    selected_product = Enum.random(@customers[random_customer])

    # Publish the order to the "orders" queue
    AMQP.Basic.publish(channel, "", @queue_name, "#{random_customer} ordered #{selected_product}")
    IO.puts("#{random_customer} ordered #{selected_product}")

    # Schedule the next order
    Process.send_after(self(), :send_order, @interval)

    {:noreply, state}
  end

end
