import logging
from logging import Formatter, StreamHandler

LOG_FORMAT = '[%(asctime)s %(levelname)s] %(name)s - %(threadName)s - %(message)s'


def init_logger():
    handlers = []

    formatter = Formatter(LOG_FORMAT)
    f_handler = StreamHandler()

    f_handler.setFormatter(formatter)
    f_handler.setLevel(logging.INFO)
    handlers.append(f_handler)

    logging.basicConfig(level=logging.DEBUG, handlers=handlers)