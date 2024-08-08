import logging
from uninuvola_init.args import args

# Logging settings
## TODO: salvare logs su file ?
## TODO: consider using structlog
logging.basicConfig(
    level=args.verbose.upper(),
    format='%(asctime)s - %(levelname)s: %(message)s',
)

logger = logging.getLogger()
