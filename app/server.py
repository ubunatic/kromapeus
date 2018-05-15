from prometheus_client import start_http_server, Summary
import random, time, sys, logging

log = logging.getLogger(__name__)

# Create a metric to track time spent and requests made.
REQUEST_TIME = Summary('request_processing_seconds', 'Time spent processing request')


# Decorate function with metric.
@REQUEST_TIME.time()
def process_request(t):
    """A dummy function that takes some time."""
    time.sleep(t)
    return True


def main(port):
    logging.basicConfig(level=logging.INFO)
    # Start up the server to expose the metrics.
    port = int(port)
    log.info("starting prometheus http server at http://0.0.0.0:%d", port)
    start_http_server(port)
    # Generate some requests.
    i = 0
    log.info("starting to process requests")
    while True:
        process_request(random.random())
        sys.stderr.write('.'); sys.stderr.flush()
        i += 1
        if i % 50 == 0: sys.stderr.write('{}\n'.format(i))


if __name__ == '__main__': main(*sys.argv[1:])

