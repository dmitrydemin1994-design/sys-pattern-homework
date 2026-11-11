import pika
import time

from settings import URI

params = pika.URLParameters(URI)
conn = pika.BlockingConnection(params)
channel = conn.channel()


def callback(ch, method, properties, body) -> None:
    # print(ch, method, properties, body)
    time.sleep(1)
    print(body)


channel.basic_consume(
    queue="hello",
    on_message_callback=callback,
    auto_ack=True,
    consumer_tag="netology_consumer",
)

if __name__ == "__main__":
    channel.start_consuming()
