import sys
import hashlib
from ldap3 import Server, Connection, ALL
from ldap3.core.exceptions import LDAPException, LDAPBindError, LDAPEntryAlreadyExistsResult
from uninuvola_init.logger import logger
from uninuvola_init.configs import configs


class LdapManager():
    """openLDAP Manager

    This class is able to fully prepare openLDAP to be used in production.
    """

    conn = None

    def __init__(self, envfile=".env"):
        logger.debug('Initializing connection')

        self.__envfile = envfile

        self.server_uri = f"ldap://{configs['openldap']['ip']}:{configs['openldap']['port']}"
        self.dc = configs['openldap']['dc']
        self.ou_groups = configs['openldap']['ougroups']
        self.ou_users = configs['openldap']['ouusers']
        self.conn_str = f"cn={configs['openldap']['user']},{self.dc}"

        # WARNING: no longer needed.
        self.USERS = [
            {'user_id':'nv98001', 'first_name': 'nicolo', 'last_name': 'vescera', 'password': '1234patata', 'ou':self.ou_users, 'uid':1000, 'gid':501},
            {'user_id':'ff99003', 'first_name': 'fabrizio', 'last_name': 'fagiolo', 'password': '1234patata', 'ou':self.ou_users, 'uid':1001, 'gid':501},
            {'user_id':'mirko', 'first_name': 'mirko', 'last_name': 'mariotti', 'password': '1234patata', 'ou':self.ou_users, 'uid':1002, 'gid':500},
        ]

        logger.debug(
            'Loaded configs: server_uri: %s, dc: %s, ou_groups: %s, ou_users %s, conn_str: %s',
            self.server_uri,
            self.dc,
            self.ou_groups,
            self.ou_users,
            self.conn_str,
        )
        logger.debug('USERS: %s', self.USERS)

        self.__auth()

    def __auth(self):
        """Authenticate to openLDAP server

        Must be used only once inside the constructor.
        """
        if self.conn is None:
            logger.debug("Connecting to %s", self.server_uri)

            try:
                # Provide the hostname and port number of the openLDAP
                server = Server(self.server_uri, get_info=ALL)
                logger.debug('Server: %s', server)

                # username and password can be configured during openldap setup
                connection = Connection(
                    server,
                    user=self.conn_str,
                    password=configs['openldap']['password'],
                    raise_exceptions=True,
                )
                logger.debug('Connection: %s', connection)

                bind_response = connection.bind() # Returns True or False
                logger.debug('Bind connection: %s', bind_response)

                if bind_response is False:
                    logger.error("Binding error !")
                    sys.exit(1)

            except LDAPBindError as e:
                logger.error(e)
                sys.exit(1)

            self.conn = connection
            logger.debug("Connection: %s", self.conn)

            logger.info("Successfully connected !")

    def __add_organizational_units(self, ou_name: str) -> str:
        """Creates a new openLDAP's Organizational Unit with given name

        Args:
            ou_name (str): OrganizationalUnit's name

        Returns:
            response (str): operation result status.

        """
        ldap_attr = {
            'objectClass': ['top', 'organizationalUnit']
        }
        dn = f'ou={ou_name},{self.dc}'

        logger.debug("ADD REQ: dn: %s, attr: %s", dn, ldap_attr)

        try:
            response = self.conn.add(
                dn,
                attributes=ldap_attr,
            )
            logger.debug("Respone: %s", response)

        except LDAPEntryAlreadyExistsResult as e:
            logger.warning(e)
            response = "skip"
            # response = f"WARNING - {e}"

        except LDAPException as e:
            logger.error(e)
            sys.exit(1)

        return response

    def __add_posixgroup(self, group_name: str, group_id: int) -> str:
        """Creates an openLDAP's PosixGroup with given name

        Args:
            group_name (str): PosixGroup's name
            group_id (int): PosixGroup's id

        Returns:
            response (str): operation result status.

        """
        ldap_attr = {
            'objectClass': ['top', 'posixGroup'],
            'gidNumber': f'{group_id}',
        }
        dn = f'cn={group_name},ou={self.ou_groups},{self.dc}'

        logger.debug("ADD REQ: dn: %s, attr: %s", dn, ldap_attr)

        try:
            response = self.conn.add(
                dn,
                attributes=ldap_attr,
            )
            logger.debug("Respone: %s", response)

        except LDAPEntryAlreadyExistsResult as e:
            logger.warning(e)
            response = "skip"
            # response = f"WARNING - {e}"

        except LDAPException as e:
            logger.error(e)
            sys.exit(1)

        return response

    # WARNING: users are not needed in production !!
    def __add_user(self, user_id: str, first_name: str, last_name: str, password: str, ou :str, uid: int, gid: int) -> str:
        """Creates an openLDAP's user with given infos.

        > [!WARNING]
        > This function is not used ! Users creation is no more needed

        Args:
            user_id (str): User's unique username
            first_name (str): User's first name
            last_name (str): User's last name
            password (str): User's password
            ou: User's OrganizationalUnit name
            uid (int): User's id
            gid (int): Users' group id

        Returns:
            response (str): operation result status.

        """
        common_name = f'{first_name} {last_name}'

        ldap_attr = {
            'givenName': first_name,
            'sn': last_name,
            'cn': common_name,
            'uid': user_id,
            'userPassword': password, # WARNING: clear password !!
            'uidNumber': f'{uid}',
            'gidNumber': f'{gid}',
            'homeDirectory': f'/home/user/{user_id}',
            'objectClass': ['inetOrgPerson', 'posixAccount', 'top'],
        }
        dn = f'cn={common_name},ou={ou},{self.dc}'

        logger.debug("ADD REQ: dn: %s, attr: %s", dn, ldap_attr)

        try:
            response = self.conn.add(
                dn,
                attributes=ldap_attr,
            )
            logger.debug("Respone: %s", response)

        except LDAPEntryAlreadyExistsResult as e:
            logger.warning(e)
            response = "skip"
            # response = f"WARNING - {e}"

        except LDAPException as e:
            logger.error(e)
            sys.exit(1)

        return response

    def add_groups(self, starting_gid=500, groups=('admin', 'users',)):
        """Creates given Groups

        Group's id starts from `starting_gid` and then is incremented by 1.

        Args:
          starting_gid:  Firs Group id (Default value = 500)
          groups:  List of all groups to create (Default value = (['users','admin'])

        Returns:

        """
        response = self.__add_organizational_units(self.ou_groups)
        logger.info("OU %s: %s", self.ou_groups, response)

        gid = starting_gid
        for g in groups:
            response = self.__add_posixgroup(g, gid)
            logger.info("CN %s: %s", g, response)

            gid += 1


    def add_users(self):
        """Creates Users

        > [!WARNING]
        > This function is not used ! Users creation is no more needed
        """
        response = self.__add_organizational_units(self.ou_users)
        logger.info("OU %s: %s", self.ou_users, response)

        for user in self.USERS:
            response = self.__add_user(**user)
            logger.info("USER: %s", response)

    def __del__(self):
        """Before object destruction, connection to openLDAP server is closed"""
        logger.info('Closing connection')
        self.conn.unbind()
        self.conn = None
