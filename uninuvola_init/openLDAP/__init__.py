from uninuvola_init.logger import logger 
from uninuvola_init.configs import configs
from .api import LdapManager


def deploy():
    logger.info("Deploying OPENLDAP")

    manager = LdapManager()
    manager.add_groups(groups=configs['openldap']['groups'])
    manager.add_users()
