package main

import (
	"fmt"
	"log"
	"math/rand"
	"os"
	"strings"
	"time"

	"github.com/streadway/amqp"
)

const (
	queueName                = "orders"
	chanceOfHeavyWorkload    = 5
	timeToReadinessInSeconds = 7
	timeToProcessInSeconds   = 1
	reconnectDelay           = 5 * time.Second
)

func main() {
	// Get RabbitMQ host replicas from the environment
	rabbitMQNodes := getRabbitMQNodes()

	// Define the required variables
	var conn *amqp.Connection
	var ch *amqp.Channel
	var err error

	for {
		// Attempt to connect to RabbitMQ nodes
		for _, node := range rabbitMQNodes {
			log.Printf("Trying to connect to RabbitMQ node: %s...", node)
			conn, err = connectToRabbitMQ(node)
			if err == nil {
				log.Printf("Connected to RabbitMQ node: %s", node)

				// Open a channel
				ch, err = conn.Channel()
				if err != nil {
					log.Printf("Failed to open a channel: %v", err)
					conn.Close()
					continue
				}

				// Start consuming messages
				err = startConsuming(ch)
				if err != nil {
					log.Printf("Error while consuming messages: %v", err)
					ch.Close()
					conn.Close()
					continue
				}

				// Wait indefinitely or until connection fails
				waitForConnectionLoss(conn)
			}

			log.Printf("Failed to connect to RabbitMQ node: %s, Error: %v", node, err)
		}

		log.Printf("All nodes failed, retrying after %v...", reconnectDelay)
		time.Sleep(reconnectDelay)
	}
}

func connectToRabbitMQ(node string) (*amqp.Connection, error) {
	// Get RabbitMQ username and password from the environment
	amqpUsername := getEnv("RABBITMQ_USERNAME", "order")
	amqpPassword := getEnv("RABBITMQ_PASSWORD", "order")

	// Connect to the rabbitmq node
	connectionString := fmt.Sprintf("amqp://%s:%s@%s/", amqpUsername, amqpPassword, node)
	conn, err := amqp.Dial(connectionString)
	if err != nil {
		return nil, err
	}

	return conn, nil
}

// The function responsible for consuming the messages
func startConsuming(ch *amqp.Channel) error {
	msgs, err := ch.Consume(
		queueName,
		"",
		false,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to register a consumer: %v", err)
	}

	go func() {
		for d := range msgs {
			processMessage(d.Body, ch, d.DeliveryTag)
		}
	}()

	log.Println("Waiting for messages. Press CTRL+C to exit.")
	return nil
}

func waitForConnectionLoss(conn *amqp.Connection) {
	notifyClose := conn.NotifyClose(make(chan *amqp.Error))
	log.Println("Listening for RabbitMQ connection closure...")

	// Block until a closure notification is received
	err := <-notifyClose
	if err != nil {
		log.Printf("Connection closed: %v", err)
	}
}

func processMessage(body []byte, ch *amqp.Channel, deliveryTag uint64) {
	if rand.Intn(chanceOfHeavyWorkload) == 0 {
		log.Printf("Heavy workload detected. Sleeping for %d seconds...", timeToReadinessInSeconds)
		time.Sleep(time.Duration(timeToReadinessInSeconds) * time.Second)
	}

	log.Printf("Received order: %s", string(body))
	time.Sleep(time.Duration(timeToProcessInSeconds) * time.Second)
	log.Printf("Processed order: %s", string(body))

	if err := ch.Ack(deliveryTag, false); err != nil {
		log.Printf("Failed to acknowledge message: %v", err)
	}
}

// A helper function to get environment variables with fallback
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}

// A helper function to get RabbitMQ nodes from the environment
func getRabbitMQNodes() []string {
	nodesEnv := getEnv("RABBITMQ_NODES", "rabbitmq")
	nodes := strings.Split(nodesEnv, ",")
	return nodes
}
