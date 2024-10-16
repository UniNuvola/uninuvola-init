# Table of Contents

* [\_\_init\_\_](#__init__)
* [\_\_main\_\_](#__main__)
* [cli](#cli)
  * [main](#cli.main)
* [args](#args)
* [configs](#configs)
* [logger](#logger)
* [openLDAP](#openLDAP)
  * [deploy](#openLDAP.deploy)
* [openLDAP.api](#openLDAP.api)
  * [LdapManager](#openLDAP.api.LdapManager)
    * [add\_groups](#openLDAP.api.LdapManager.add_groups)
    * [add\_users](#openLDAP.api.LdapManager.add_users)
    * [\_\_del\_\_](#openLDAP.api.LdapManager.__del__)
* [vault](#vault)
  * [deploy](#vault.deploy)
* [vault.api](#vault.api)
  * [SECRETS\_FILE](#vault.api.SECRETS_FILE)
  * [CLIENT\_IP](#vault.api.CLIENT_IP)
  * [init](#vault.api.init)
  * [unseal](#vault.api.unseal)
  * [enable\_openldap](#vault.api.enable_openldap)
  * [oidc](#vault.api.oidc)
  * [create\_group](#vault.api.create_group)
  * [get\_config](#vault.api.get_config)
  * [read](#vault.api.read)
  * [logout](#vault.api.logout)
  * [custom\_ui](#vault.api.custom_ui)

<a id="__init__"></a>

# \_\_init\_\_

<a id="__main__"></a>

# \_\_main\_\_

<a id="cli"></a>

# cli

CLI commands module

<a id="cli.main"></a>

#### main

```python
def main()
```

Main executable function

<a id="args"></a>

# args

CLI Argument parser.

All available arguments are:

- `-v`, `--verbose` `LEVEL`: logging level. Default is 'INFO'. 
                             Available: `[INFO, DEBUG]`
- `--services` `SERVICES`  : serice or services to configure.
                             Could be empty (all services).
                             Available: `[ldap, vault]`
- `config`                 : config file path. Must be in YAML format.

<a id="configs"></a>

# configs

<a id="logger"></a>

# logger

<a id="openLDAP"></a>

# openLDAP

<a id="openLDAP.deploy"></a>

#### deploy

```python
def deploy()
```

Deploy procedure.

Runs every CLI commands needed for auto-deploy a new openLDAP container.
In order, this function does:

1. Connects to openLDAP
1. Creates given groups

<a id="openLDAP.api"></a>

# openLDAP.api

<a id="openLDAP.api.LdapManager"></a>

## LdapManager Objects

```python
class LdapManager()
```

openLDAP Manager

This class is able to fully prepare openLDAP to be used in production.

<a id="openLDAP.api.LdapManager.add_groups"></a>

#### add\_groups

```python
def add_groups(starting_gid=500, groups=(
    'admin',
    'users',
))
```

Creates given Groups

Group's id starts from `starting_gid` and then is incremented by 1.

**Arguments**:

- `starting_gid` - Firs Group id (Default value = 500)
- `groups` - List of all groups to create (Default value = (['users','admin'])
  

<a id="openLDAP.api.LdapManager.add_users"></a>

#### add\_users

```python
def add_users()
```

Creates Users

> [!WARNING]
> This function is not used ! Users creation is no more needed

<a id="openLDAP.api.LdapManager.__del__"></a>

#### \_\_del\_\_

```python
def __del__()
```

Before object destruction, connection to openLDAP server is closed

<a id="vault"></a>

# vault

<a id="vault.deploy"></a>

#### deploy

```python
def deploy()
```

Deploy procedure.

Runs every CLI commands needed for auto-deploy a new Vault container.
In order, this function does:

1. Init Vault procedure (generates keys and secrets)
1. Unseal the Vault
1. Enables openLDAP auth method
1. Creates given Vault's groups (according to openLDAP's groups)
1. Enable custom UI
1. Creates OIDC apps

<a id="vault.api"></a>

# vault.api

Vault's API Module

Here are stored all needed functions to initialize and set up Vault.

<a id="vault.api.SECRETS_FILE"></a>

#### SECRETS\_FILE

Secrets file path

<a id="vault.api.CLIENT_IP"></a>

#### CLIENT\_IP

Vault Server URI
```<PROTOCOL>://<VAULT'S IP>:<VAULT'S PORT>```

<a id="vault.api.init"></a>

#### init

```python
def init(shares=5, threshold=3)
```

Initialize Vault when first created.

Initialize the Vault container and save the resulting secrets (in json format)
in .env file.

**Arguments**:

- `shares` _int_ - (Default value = 5)
- `threshold` _int_ - (Default value = 3)
  

<a id="vault.api.unseal"></a>

#### unseal

```python
def unseal()
```

Unseal Vault.

Unseal Vault by using 3 keys (secrets) generated during the init phase.

<a id="vault.api.enable_openldap"></a>

#### enable\_openldap

```python
def enable_openldap(ip: str,
                    port: str,
                    dc: str,
                    user: str,
                    password: str,
                    ldap_auth_path="ldap",
                    description="auth method")
```

Enable openldap/ auth method.

**Arguments**:

- `ip` _str_ - openLDAP's IP address
- `port` _str_ - openLDAP's IP port
- `dc` _str_ - dc string. Example: `dc=uninuvola,dc=unipg,dc=it`
- `user` _str_ - openLDAP's username
- `password` _str_ - openLDAP's password
- `ldap_auth_path` _str, optional_ - custom authenticator path.
  This will create a `/auth/<ldap_auth_path>` uri in Vault. (Default value = "ldap")
- `description` _str, optional_ - optional authenticator description (Default value = "auth method")
  

<a id="vault.api.oidc"></a>

#### oidc

```python
def oidc(appname: str, scopes: list, providername: str, redirect_uris: str)
```

Configure Vault as an OIDC Provider

This function in order does:

- Creates the Application with the redirect uris,
- Creates the default Scopes
- Set the default provider configs

**Arguments**:

- `appname` _str_ - OIDC Application name
- `scopes` _list_ - a list of scopes. A scope is a json formatted string
- `providername` _str_ - OIDC Application provider name
- `redirect_uris` _str_ - OIDC Application allowed redirect url
  

<a id="vault.api.create_group"></a>

#### create\_group

```python
def create_group(group_name: str)
```

Create a group and alias with given name.

Groups must be manually created (unlike Entities) in order to enable Vault to
accept openLDAP groups. Aliases are used to link a Vault's Group to an external
authenticator (e.g. openLDAP).

**Arguments**:

- `group_name` _str_ - group name
  

<a id="vault.api.get_config"></a>

#### get\_config

```python
def get_config(appname: str, filename: str, secretlen=16)
```

Generates config file for given OIDC Application.

Generates a `.env` file with the required settings:
- OIDC Client ID
- OIDC Client Secret
- OIDC Conf URL
- A Secret Key
- Redis ip and password

**Arguments**:

- `appname` _str_ - OIDC Application name
- `filename` _str_ - Resulting config file path
- `secretlen` _int_ - Secret length (Default value = 16)
  

<a id="vault.api.read"></a>

#### read

```python
def read(secret: str)
```

Read specified Vault secrets config.

**Arguments**:

- `secret` _str_ - Secret to read. Could be one of the following
  - `keys`: secret keys used to unseal Vault
  - `token`: the root token used to authenticate to Vault
  - `all`: both "keys" and "token"
  

<a id="vault.api.logout"></a>

#### logout

```python
def logout()
```

Logs out from Vault

<a id="vault.api.custom_ui"></a>

#### custom\_ui

```python
def custom_ui()
```

Generates custom Vault's auth page by
foring to display only LDAP form

