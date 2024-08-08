from uninuvola_init import vault
from uninuvola_init import openLDAP
from uninuvola_init.logger import logger
from uninuvola_init.args import args
from uninuvola_init.config_parser import config_parser

def main():
    logger.info("hello world !")
    logger.debug("Debug info")
    configs = config_parser(args.config)
