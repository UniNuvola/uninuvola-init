import sys
from yaml import safe_load, YAMLError
from uninuvola_init.logger import logger
from uninuvola_init.args import args


def _config_parser(path) -> dict:
    try:
        with open(path, 'r') as stream:
            try:
                content = safe_load(stream)

                logger.debug("Config file '%s': %s", path, content)

                return content

            except YAMLError as e:
                logger.error("A problem occur with filei '%s':\n%s", path, e)
                sys.exit(1)

    except FileNotFoundError as e:
        logger.error("%s: %s", e, path)
        sys.exit(1)


configs = _config_parser(args.config)
