import json
from pathlib import Path

from command_center import run_command_center


BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"


def load_config():
    with CONFIG_PATH.open("r", encoding="utf-8") as f:
        return json.load(f)


def main():
    run_command_center(load_config(), BASE_DIR)


if __name__ == "__main__":
    main()
