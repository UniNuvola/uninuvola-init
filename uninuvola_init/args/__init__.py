import argparse

_parser = argparse.ArgumentParser()
_parser.add_argument(
    "-v", "--verbose",
    type=str,
    default="INFO",
    choices=['INFO', 'DEBUG'], # TODO: aggiungere warning e altri ?
    help="Logging level"
    )
_parser.add_argument(
    "config", 
    type=str,
    # required=True,
    help="Config file in yaml format"
    )


args = _parser.parse_args()
