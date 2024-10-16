from uninuvola_init.logger import logger 
from .api import LdapManager


def deploy():
    """Deploy procedure.

    Runs every CLI commands needed for auto-deploy a new openLDAP container.
    In order, this function does:
    
    1. Connects to openLDAP
    1. Creates given groups
    """
    logger.info("Deploying OPENLDAP")

    manager = LdapManager()
    manager.add_groups()
    manager.add_users()
