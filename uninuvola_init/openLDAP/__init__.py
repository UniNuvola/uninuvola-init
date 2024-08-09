from uninuvola_init.logger import logger 
from .api import LdapManager


def deploy():
    logger.info("Deploying OPENLDAP")

    manager = LdapManager()
    manager.add_groups()
    manager.add_users()
