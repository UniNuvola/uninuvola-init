import json
import sys
import secrets
import hvac
from uninuvola_init.logger import logger
# from uninuvola_init.args import args
from uninuvola_init.configs import configs


SECRETS_FILE = ".secrets"
CLIENT_IP = f"{configs['vault']['protocol']}://{configs['vault']['ip']}:{configs['vault']['port']}" # TODO: CLIENT_URI

logger.debug("Vault IP: %s", CLIENT_IP)
_client = hvac.Client(url=CLIENT_IP)


def _auth():
    """Authenticate client using saved secrets.
    """

    logger.info("Client Authenticated: %s", _client.is_authenticated())
    logger.info("Client Inizialized: %s", _client.sys.is_initialized())

    # already initialized, return token and keys
    if _client.token:
        return _client.token, _client.keys

    logger.info("Loading secrets ...")

    try:
        with open(SECRETS_FILE, "r") as fp:
            _secrets = json.load(fp)

    except FileNotFoundError:
        logger.error("No config file found !")
        sys.exit(1)

    root_token = _secrets['root_token']
    keys = _secrets['keys']

    logger.debug("root_token: %s, keys: %s", root_token, keys)
    logger.info("Authenticating ...")

    _client.token = root_token
    _client.keys = keys

    return root_token, keys


def init(shares=5, threshold=3):
    """Initialize Vault when first created.

    Initialize the Vault container and save the resulting secrets (in json format)
    in .env file.
    """

    logger.info("Running init procedure")
    logger.debug("shares: %s, threshold: %s", shares, threshold)

    result = _client.sys.initialize(shares, threshold)

    root_token = result['root_token']
    keys = result['keys']

    logger.debug("root_token: %s, keys: %s", root_token, keys)
    logger.info("Client Inizialized: %s", _client.sys.is_initialized())

    logger.info("Saving secrets")
    with open(SECRETS_FILE, "w") as fp:
        json.dump(result , fp)


def unseal():
    """Unseal the Vault.

    Unseal the Vault by using 3 keys (secrets) generated during the init phase.
    """

    _, keys = _auth()

    logger.info("Running Useal procedure")
    logger.info("Client Sealed: %s", _client.sys.is_sealed())

    # Unseal a Vault cluster with individual keys
    unseal_response1 = _client.sys.submit_unseal_key(keys[0])
    unseal_response2 = _client.sys.submit_unseal_key(keys[1])
    unseal_response3 = _client.sys.submit_unseal_key(keys[2])

    logger.debug("Unseal Response 1: %s", unseal_response1)
    logger.debug("Unseal Response 2: %s", unseal_response2)
    logger.debug("Unseal Response 3: %s", unseal_response3)

    logger.info("Client Sealed: %s", _client.sys.is_sealed())

# WARNING: could not be usefeull
# def create_entity():
#     """Creates entities.
#
#     Creates 2 test entities (alice and bob) with respective aliases.
#     Entity and Alias are needed for userpass/ auth method.
#     """
#
#     _ = _auth()
#
#     logger.info("Creating entities")
#
#     accessor = _client.sys.list_auth_methods()['userpass/']['accessor']
#     logger.debug("userpass/ accessor: %s", accessor)
#
#     for user in USERS:
#         create_response = _client.secrets.identity.create_or_update_entity(
#             name=user['name'],
#             metadata=dict(email=user['email'], username=user['username']),
#         )
#         entity_id = create_response['data']['id']
#         logger.info(f"Entity ID for {user['name']} is: {entity_id}")
#
#         create_response = _client.secrets.identity.create_or_update_entity_alias(
#                 name=user['name'],
#                 canonical_id=entity_id,
#                 mount_accessor=accessor,
#         )
#         alias_id = create_response['data']['id']
#         logger.info(f"Alias ID for {user['name']} is: {alias_id}")


def enable_openldap(ip, port, dc, user, password, ldap_auth_path="ldap", description="auth method"):
    """Enable openldap/ auth method.
    """

    _ = _auth()

    logger.info("Enabling ldap/")

    _client.sys.enable_auth_method(
        method_type='ldap',
        description=description,
        path=ldap_auth_path,
    )

    _client.auth.ldap.configure(
        user_dn=f'ou=users,{dc}',
        group_dn=f'ou=groups,{dc}',
        url=f'ldap://{ip}:{port}',
        bind_dn=f'cn={user},{dc}',
        bind_pass=password,
        user_attr='uid',
        group_attr='cn',
    )

# def enable_userpass():
#     """Enable userpass/ auth method.
#     """
#
#     _ = _auth()
#
#     logger.info("Enabling userpass/")
#     _client.sys.enable_auth_method('userpass')
#
#
# def set_users():
#     """Set userpass/ users.
#
#     Creates 2 users (alice and bob) inside the userpass/ auth methods and sets the passowrds.
#     Users' names are the same of entity names, this put in a relation entity and userpass/
#     users preventing to generate new entities.
#     """
#
#     _ = _auth()
#
#     logger.info("Setting users for userpass/")
#
#     for user in USERS:
#         create_response = _client.auth.userpass.create_or_update_user(username=user['name'], password=user['name'])
#         logger.debug(f"{user['name']} response: {create_response}")


def oidc(appname, scopename, providername, redirect_uris):
    """Configure Vault as an OIDC Provider

    \b
    - Creates the Application with the redirect uris,
    - Creates the default Scope
    - Set the default provider configs
    """
    _ = _auth()

    # Create application
    # TODO: set inside config.yaml ??
    app_config = {
        "access_token_ttl": "24h",
        "assignments": [
            "allow_all "
        ],
        "client_type": "confidential",
        "id_token_ttl": "24h",
        "key": "default",
        "redirect_uris": [
            # configs['vault']['oidc']['redirect_uris']
            redirect_uris,
        ]
    }

    logger.info("Creating application: %s", appname)
    logger.debug(app_config)

    _client.write_data(
        path=f"/identity/oidc/client/{appname}",
        data=app_config
    )

    # Create scope
    _accessor = _client.read('/sys/auth/ldap')['data']['accessor']
    scope_config = {
        "description": "",
        "template": f"""
        {{
            "metadata": {{{{identity.entity.aliases.{_accessor}.metadata}}}}
        }}
        """
        # "template": f"""
        # {{
        #     "contact": {{
        #         "email": {{{{identity.entity.metadata.email}}}},
        #         "username": {{{{identity.entity.metadata.username}}}},
        #         "name": {{{{identity.entity.aliases.{_accessor}.metadata}}}}
        #     }}
        # }}
        # """
    }

    logger.info("Creating application scope: %s", appname)
    logger.debug(scope_config)

    _client.write_data(
        path=f"/identity/oidc/scope/{scopename}",
        data=scope_config
    )

    # Update Provider
    client_id = _client.read(f"/identity/oidc/client/{appname}")['data']['client_id']

    provider_config = {
        "allowed_client_ids": [ client_id ],
        # "issuer": "http://localhost:8200",
        "issuer": CLIENT_IP,
        "scopes_supported": [
            scopename
        ]
    }

    logger.info("Creating application provider: %s", providername)
    logger.debug(provider_config)

    _client.write_data(
        path=f"/identity/oidc/provider/{providername}",
        data=provider_config
    )


def create_group():
    """Create the default group.
    """

    _ = _auth()

    logger.info("Creating default group")

    create_response = _client.secrets.identity.create_or_update_group(
            name='default',
            # metadata=dict(extra_data='we gots em'),
    )

    group_id = create_response['data']['id']
    logger.info("Group ID for 'default' is: %s", group_id)


def get_config(appname, filename, secretlen=16):
    """Generate config for the WepApp

    \b
    Generates a .env file with the required settings:
        - OIDC Client ID
        - OIDC Client Secret
        - OIDC Conf URL
        - A Secret Key
        - Admin users
    """
    _ = _auth()

    env_data = {}

    logger.info("Generating config for Application %s", appname)

    respone = _client.read(f"/identity/oidc/client/{appname}")
    logger.debug(respone)

    env_data['client_id'] = respone['data']['client_id']
    env_data['client_secret'] = respone['data']['client_secret']
    env_data['conf_url'] = f"{CLIENT_IP}/v1/identity/oidc/provider/{appname}/.well-known/openid-configuration" # TODO: automatico ?
    env_data['secret_key'] = secrets.token_urlsafe(secretlen)
    env_data['admin_users'] = "\'[\"alice.alice@unipg.it\", \"prova@unipg.it\", \"eliasforna@gmail.com\"]\'"
    env_data['redis_ip'] = configs['redis']['ip']
    env_data['redis_password'] = configs['redis']['password']

    logger.debug(env_data)
    logger.info("Writing %s data", filename)

    with open(filename, 'w') as f:
        f.write(f"VAULT_CLIENT_ID={env_data['client_id']}\n")
        f.write(f"VAULT_CLIENT_SECRET={env_data['client_secret']}\n")
        f.write(f"VAULT_CONF_URL={env_data['conf_url']}\n")
        f.write(f"SECRET_KEY={env_data['secret_key']}\n")
        f.write(f"ADMIN_USERS={env_data['admin_users']}\n")
        f.write(f"REDIS_IP={env_data['redis_ip']}\n")
        f.write(f"REDIS_PASSWORD={env_data['redis_password']}\n")


def read(secret):
    """Read specified Vault secrets config

    \b
    You can read:
        - "keys": secret keys used to unseal Vault
        - "token": the root token used to authenticate to Vault
        - "all": both "keys" and "token"

    """

    _ = _auth()

    try:
        with open(SECRETS_FILE, "r") as f:
            _secrets = json.load(f)

            to_print = {}

            if secret == 'all':
                to_print = _secrets
            else:
                to_print = _secrets['keys'] if secret == 'keys' else _secrets['root_token']

            logger.info("Secrets: %s", to_print)

    except OSError as e:
        logger.error("No config file found !\n%s", e)


def logout():
    logger.info("Loggin out")

    # revoke_token=True revoke the root_token created !
    _client.logout(revoke_token=False)
    _client.keys = None


def custom_ui():
    _ = _auth()
    
    tune_conf = {
        'listing_visibility': 'unauth',
    }

    logger.info("Changing Vault UI: ldap default login method")
    logger.debug(tune_conf)

    _client.write_data(
        path="sys/auth/ldap/tune",
        data=tune_conf,
    )
