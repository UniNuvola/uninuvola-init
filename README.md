# uninuvola-init

Kickstarter script for all uninuvola's software

## Config

Create a `.env` file with the following config:

```yaml
general:
  project:
  domain:

vault:
  ip:
  port:
  protocol:
  oidcs:
    web:
      appname:
      scopename:
      providername:
      redirect_uris:
      secretfile:
    jupyter:
      appname:
      scopename:
      providername:
      redirect_uris:
      secretfile:

openldap:
  ip:
  port:
  dc:
  ougroups:
  ouusers:
  user:
  readonlyuser:

ldapadmin:
  ip:

redis:
  ip:
  port:
  username:

ldapsync:
  ip:
```
