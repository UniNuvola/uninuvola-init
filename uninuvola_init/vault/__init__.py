from uninuvola_init.configs import configs
from uninuvola_init.logger import logger
from . import api


def deploy():
    """Deploy procedure.

    Runs every CLI commands needed for auto-deploy a new Vault container.
    """

    logger.info("Deploying VAULT")

    api.init()
    api.unseal()
    api.enable_openldap(
        ip=configs['openldap']['ip'],
        port=configs['openldap']['port'],
        dc=configs['openldap']['dc'],
        user=configs['openldap']['readonlyuser'],
        password=configs['openldap']['readonlypassword'],
    )
    # api.enable_userpass()
    # api.create_entity()
    # api.set_users()
    api.create_group()
    api.custom_ui()

    # creating oidc application and retriving configs
    for _, oidc_conf in configs['vault']['oidcs'].items():
        api.oidc(
            appname=oidc_conf['appname'],
            scopes=oidc_conf['scopes'],
            providername=oidc_conf['providername'],
            redirect_uris=oidc_conf['redirect_uris'],
        )

        api.get_config(appname=oidc_conf['appname'], filename=oidc_conf['secretfile'])
    
    api.logout()
