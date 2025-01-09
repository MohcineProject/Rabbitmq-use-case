defmodule OrderCreator do

  use GenServer

  @interval 2000
  @customers %{
    "John" => ["strawberries", "watermelon", "bananas"],
    "Alice" => ["smartphone", "laptop", "headphones"],
    "Mike" => ["carrots", "broccoli", "spinach"],
    "Sarah" => ["coffee", "tea", "orange juice"],
    "Emma" => ["novel", "self-help book", "cookbook"]
  }


  def start_link(_) do
    GenServer.start_link(__MODULE__, _, name: __MODULE__)
  end


  def init(_) do
    :times.send_interval(@interval , :send_order)
    {:ok,%{}}
  end

  def handle_info(:send_order , state) do


    # Selecting a random customer
    customer_names = Map.keys(@customers)
    random_index = :rand.uniform(length(customer_names)) - 1
    random_customer = Enum.at(customer_names, random_index)

    # Selecting a random product from his list
    random_index = :rand.uniform(length(customer_names)) - 1
    selected_product = Enum.at(@customers[random_customer] , random_index)

    # Connect to RabbitMQ and publish the order
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Queue.declare(channel, "orders")
    AMQP.Basic.publish(channel, "", "orders", "#{random_customer} ordered #{selected_product}")

    # Close the channel and connection
    AMQP.Channel.close(channel)
    AMQP.Connection.close(connection)


    IO.puts("Random customer: #{random_customer}")
    {:noreply, state}

  end

end
