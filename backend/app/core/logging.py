import logging
import sys
import warnings
from pathlib import Path

LOG_FORMAT = (
    "%(asctime)s | %(levelname)-5s | %(name)s:%(lineno)d | %(funcName)s | %(message)s"
)


def setup_logging(level: int = logging.DEBUG) -> None:
    root = logging.getLogger()
    root.setLevel(level)

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(level)
    handler.setFormatter(logging.Formatter(LOG_FORMAT, datefmt="%H:%M:%S"))
    root.handlers = [handler]

    # Quiet noisy third-party loggers
    for name in ("httpx", "httpcore", "sqlalchemy.engine", "uvicorn.access",
                 "dashscope", "openai", "openai._base_client", "faiss",
                 "faiss.loader", "sentence_transformers", "huggingface_hub",
                 "passlib", "passlib.handlers", "paddle", "paddlex"):
        logging.getLogger(name).setLevel(logging.WARNING)

    # Suppress harmless third-party warnings
    warnings.filterwarnings("ignore", message=".*protected namespace.*")
    warnings.filterwarnings("ignore", message=".*urllib3.*")
    warnings.filterwarnings("ignore", message=".*chardet.*")
    warnings.filterwarnings("ignore", message=".*ccache.*")
    warnings.filterwarnings("ignore", message=".*crypt.*deprecated.*")
    warnings.filterwarnings("ignore", category=DeprecationWarning, module="pydantic")
    warnings.filterwarnings("ignore", category=DeprecationWarning, module="passlib")
    warnings.filterwarnings("ignore", category=DeprecationWarning, module="jose")


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
