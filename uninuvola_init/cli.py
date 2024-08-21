from uninuvola_init import vault
from uninuvola_init import openLDAP


def main():
    openLDAP.deploy()
    vault.deploy()
