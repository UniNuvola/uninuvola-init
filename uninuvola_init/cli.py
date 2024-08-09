from uninuvola_init import vault
from uninuvola_init import openLDAP
from uninuvola_init.logger import logger
from uninuvola_init.args import args
from uninuvola_init.configs import configs

def main():
    vault.deploy()
