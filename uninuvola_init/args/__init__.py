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
_parser.add_argument(
    "--services", 
    type=str,
    nargs='+',
    # default=[]
    help="""Specify which service should be configured.
    Available:
        - 'ldap'
        - 'vault'
    """
    )


args = _parser.parse_args()
