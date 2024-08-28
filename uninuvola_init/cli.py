import sys
from uninuvola_init import vault
from uninuvola_init import openLDAP
from uninuvola_init.args import args
from uninuvola_init.logger import logger


def main():
    logger.debug("CLI ARGS: %s", args)

    _all_services = {
        'vault': vault,
        'ldap': openLDAP,
    }

    if args.services is None:
        args.services = _all_services.keys()

    for serivce in args.services:
        try:
            _all_services[serivce].deploy()
        except KeyError:
            logger.error("Wrong service name: %s", serivce)
            sys.exit(1)
