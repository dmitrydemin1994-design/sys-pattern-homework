import pika

from settings import URI

# params = pika.ConnectionParameters('localhost')
params = pika.URLParameters(URI)
conn = pika.BlockingConnection(params)
channel = conn.channel()

channel.queue_declare(queue="test_q")

if __name__ == "__main__":

    channel.basic_publish(
        exchange="",
        routing_key="test_q",
        body="Hello, SYSDB-32! - 27.06.2024",
    )
