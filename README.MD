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

**Explanation**:

RabbitMQ supports the use of messaging queues, enabling **asynchronous communication** between microservices. This means that a consumer can delay processing a message until it’s ready, without impacting the producer, which does not have to wait for a response.

It also helps with **load balancing**, as **multiple consumers** can pull messages from the queue, preventing any single service from being overwhelmed. This reduces the burden on microservices by allowing them to handle tasks at their own pace, leading to more efficient resource usage and better fault tolerance.

In addition to that, we can implement an **acknowledgment mechanism** in RabbitMQ. This ensures that when a consumer receives a message, the message remains in the queue, waiting for the acknowledgment (ack) signal from the consumer. The consumer typically sends the ack message once it has finished processing the task. This allows messages to persist in the queue until the consumer has confirmed successful processing.

Futhermore, the queues can be made **durable**. This functionnality make it possible to persist queues declaration even if the rabbitmq server restarted. Moreover, messages can be marqued as **persistent**, which signals rabbitmq to write them in the disk memory. This approach saves the message from being lost if the rabbitmq service went down. However they came with their own tradeoffs such as increased latency because of the I/O operations to the disk, the messages are not saved the memory immediately since rabbitmq and they can be lost if the service failed before that. 

**Example in Code**:

In this example, we have two instances of the inventory service running. **They share the same queue to receive messages from the order service**. We can think of these instances as nodes in a distributed database, for example. This setup allows our inventory service to **scale horizontally**, supporting more requests.

Another important element is that in the inventory service, **we can control when we consume a message**, preventing the service from becoming overloaded, which ultimately improves fault tolerance.

Additionaly, we’ve added the **acknowledgment feature** of RabbitMQ. When a consumer receives a message, RabbitMQ does not delete it from the queue immediately. Instead, the message is marked as "in progress," making it unavailable to other consumers (e.g., the second service). It will remain in the queue until the acknowledgment is received. If the consumer that received the message crashes, for instance, and the connection is lost, RabbitMQ will re-publish the message to the queue, allowing another consumer to process it.

Finally, we have implemented **durable queues** and **persistent messages** in the simulation. This means that there is no need to redeclare the queues if the service is restarted, which can be verified by accessing the management UI. Furthermore, the persistent messages can be seen by accessing the container and naviguating to rabbitmq storage files. 

To test this elements, first access the command line of the rabbitmq container using the following : 

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

## Cluster of running services 

**Explanation**:

Rabbitmq also supports clustering. Meaning that the service can run in multiple nodes. This follows the bases of the erlang virtual machines designed for distributed systems, where we have multiple nodes that can be distributed among different machines and establish connections between them. 

From the client perspective, he can establish a connection to a first node and then if it goes down, he can try to reconnect to other replicas. This way, by configuring the client side to retry connection to other nodes in the rabbitmq cluster, the reliability of the message brocker is increased. 

We can also declare **mirrored queues**, to duplicate messages from a queue in a node to queues in other nodes. This way we ensure that if the rabbitmq main service went down, information is not lost since we can connect to other replicate services. 

**Example in Code**:

In our example we have set three containers of rabbitmq. The order and the inventory services are set to connect to the main node, the **rabbitmq** container. If this container is down ( you can turn it off in docker ), they will try to reconnect to the first duplicate, the container **rabbitmq-duplicate-1**. In its turn, if it is down, they will reconnect to the final duplicate. We can see that this feature of rabbitmq increases significantly its availability, and the message brocker is still available even after some nodes are down. 

We have also applied **mirrored queues** to replicate messages among the nodes of the cluster. This is very helpfyl in case the inventory switched to another node in the cluster since it will find the same queues along with the non consumed messages. 

In order to view this functionnality, you can access a replicate node terminal, for example : 

```sh
docker exec -it rabbitmq-duplicate-1 /bin/bash
```

And then enable management UI : 

```sh
rabbitmq-plugins enable rabbitmq_management
```


And then stop the inventory services so that queue on the primary node stores some messages, and visualize the state of the duplicate node, you will see that all the messages are forwared to its own queue ! 