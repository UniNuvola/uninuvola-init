from uninuvola_init.configs import configs
from . import api


def deploy():
    """Deploy procedure.

    Runs every CLI commands needed for auto-deploy a new Vault container.
    """

    api.init()
    api.unseal()
    # api.enable_userpass()
    # api.create_entity()
    # api.set_users()
    api.create_group()

    # creating oidc application and retriving configs
    for _, oidc_conf in configs['vault']['oidcs'].items():
        api.oidc(
            appname=oidc_conf['appname'],
            scopename=oidc_conf['scopename'],
            providername=oidc_conf['providername'],
            redirect_uris=oidc_conf['redirect_uris'],
        )

        api.get_config(appname='web', filename=oidc_conf['secretfile'])

    api.logout()
