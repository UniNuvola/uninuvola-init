from uninuvola_init import vault
from uninuvola_init import openLDAP


def main():
    vault.deploy()
    openLDAP.deploy()
