# RabbitMQ Use Case

## Introduction
This project is an illustrative example of the benefits of rabbitmq as a message broker service. It consists of a simulation of a set of an ecommerce microservices that communicate with each other, using AMQP protcol, to store the clients orders. I used multiple features of rabbitmq to give an example of its strong advantages in the context of distributed system. 


## Prerequisites
- Make sure to have docker installed and its daemon up and running
- Make sure to have docker-compose installed as well, altough it should be included with your docker installation


## How to run : 

Simply navigate to the root folder and execute the docker-compose command 

```sh 
docker-compose up -d 
``` 

This command will build all the microservices images and run the the containers. 

# Demonstrated Features

## Messaging Queues

### **Explanation**:

RabbitMQ supports the use of messaging queues, enabling **asynchronous communication** between microservices. This means that a consumer can delay processing a message until it is ready, without impacting the producer, which does not need to wait for a response.

It also helps with **load balancing**, as **multiple consumers** can pull messages from the queue, preventing any single service from being overwhelmed. This reduces the burden on microservices by allowing them to handle tasks at their own pace, leading to more efficient resource usage and better fault tolerance.

Additionally, RabbitMQ implements an **acknowledgment mechanism**. This ensures that when a consumer receives a message, the message remains in the queue, waiting for the acknowledgment (ack) signal from the consumer. The consumer typically sends the ack message once it has finished processing the task. This allows messages to persist in the queue until the consumer has confirmed successful processing.

Furthermore, queues can be made **durable**, meaning that their declaration persists even if the RabbitMQ server is restarted. Additionally, messages can be marked as **persistent**, signaling RabbitMQ to write them to disk memory. This approach ensures that messages are not lost if the RabbitMQ service goes down. However, this comes with trade-offs, such as increased latency due to I/O operations to disk. The messages are not immediately saved to memory, and they could be lost if the service fails before the write occurs.

### **Example in Code**:

In this example, we have two instances of the inventory service running. **They share the same queue to receive messages from the order service**. We can think of these instances as nodes in a distributed database. This setup allows the inventory service to **scale horizontally**, supporting more requests.

Another important element is that in the inventory service, **we can control when we consume a message**, preventing the service from becoming overloaded, which ultimately improves fault tolerance.

Additionally, we’ve incorporated the **acknowledgment feature** of RabbitMQ. When a consumer receives a message, RabbitMQ does not delete it from the queue immediately. Instead, the message is marked as "in progress," making it unavailable to other consumers (e.g., the second service). It will remain in the queue until the acknowledgment is received. If the consumer that received the message crashes or the connection is lost, RabbitMQ will re-publish the message to the queue, allowing another consumer to process it.

Finally, we have implemented **durable queues** and **persistent messages** in the simulation. This means there is no need to redeclare the queues if the service is restarted, which can be verified by accessing the management UI. Furthermore, the persistent messages can be seen by accessing the container and navigating to RabbitMQ's storage files.

To test these elements, first access the command line of the RabbitMQ container using the following:

```sh
docker exec -it rabbitmq /bin/bash
```

Then enable the management plugin : 

```sh
rabbitmq-plugins enable rabbitmq_management
```

Naviguate to the URL in your browser and check if the queue exists : 
`localhost:15672/`

Then stop the inventory services in docker desktop to stop consuming messages. Wait for some time so that queue stock some logs and then stop the order service.

At the rabbitmq terminal, stop the app and restart it : 

```sh
rabbitmqctl stop_app
rabbitmqctl start_app
```
Verify in the management UI, and you will find the queues and the messages still available. 

## Cluster of Running Services

**Explanation**:

RabbitMQ also supports **clustering**, meaning that the service can run on multiple nodes. This is based on the principles of the Erlang virtual machines, which are designed for distributed systems. Multiple nodes can be distributed across different machines and establish connections with each other.

From the client perspective, it can establish a connection to the first node. If this node goes down, the client can attempt to reconnect to other **replicas**. By configuring the client to retry connections to other nodes in the RabbitMQ cluster, the reliability of the message broker is increased.

We can also declare **Quorum Queues** to replicate messages from a queue on one node to queues on other nodes. This type of queue uses the Raft consensus protocol, where the system relies on the majority of nodes (also known as a quorum) to guarantee consistency in the replicated messages. This feature adds the constraint that for a quorum queue replicated across n nodes, we need at least n/2 + 1 functional nodes in the cluster for the queue to be accessible. This type of queue is ideal for data consistency and availability.

**Example in Code**:

In our example, we have three RabbitMQ containers. The **order** and **inventory** services are set to connect to the main node, the **rabbitmq** container. If this container goes down (you can turn it off in Docker), the services will attempt to reconnect to the first replica, **rabbitmq-duplicate-1**. If that node goes down as well, they will reconnect to the final replica. This feature of RabbitMQ significantly increases its availability, allowing the message broker to remain functional even when some nodes are down.

We have also applied **Quorum Queues** to replicate messages across the nodes in the cluster. This is particularly helpful in cases where the inventory service switches to another node in the cluster, as it will find the same queues with any unconsumed messages.

***IMPORTANT NOTE***

Since the quorum queue is replicated across three nodes in the RabbitMQ cluster, we must have at least 2 functional nodes for the queue to be available. It is possible to remove this constraint using another feature called **mirrored queues**, but they come with their own trade-offs, particularly in terms of consistency, and are no longer supported in recent versions of RabbitMQ.

To view this functionality, you can access a replicated node's terminal, for example:

```sh
docker exec -it rabbitmq-duplicate-1 /bin/bash
```

Then, enable the management UI:

```sh
rabbitmq-plugins enable rabbitmq_management
```

Next, stop the inventory services so that the queue on the primary node stores some messages. Afterward, you can check the state of the duplicate node. You will see that all the messages are forwarded to its own queue!

You can then stop the rabbitmq container, and you will notice that the order and inventory services switch to another replica, with the system remaining functional