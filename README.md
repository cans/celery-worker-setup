celery-worker
=============

A role to setup the configuration of a set of Celery workers supervised
by systemd.


Each worker has to be described through items as the one that follows:

```yaml
- app_name: 'MyApp'                      # (mandatory)
  app_variable: 'my_app'                 # (default: `celeryw_app_variable`)
  celeryd_bin: '/usr/local/bin/celery'   # (default: `celeryw_bin`)
  group: "adm"                           # (default: `celeryw_`)
  log_dir:                               # (default: `celeryw_log_dir`)
  log_filename: "%n%I"                   # (default: `celeryw_log_filename`)
  log_level: "INFO"                      # (default: `celeryw_log_level`)
  pid_filename: `%n-master.pid`          # (default: `celeryw_pid_filename`)
  queues: `%n-master.pid`                # (default: `celeryw_queues`)
```

Basically all variables in the [Role variables](#role-variables) section
below can be overriden, on a per-worker basis, in the item discribing the
worker through a key that has the same name (omitting the role namespace
prefix). The only two exceptions are the `app_name` and `app_module`
variables that you _must_ provide for each worker you define.


Requirements
------------

This role has no requirements. 


Role Variables
--------------

All variables in this role are namespaced with the prefix `celeryw_`.

### Defaults

- `celeryw_app_variable`: module level variable that hold a reference
  to the celery application (default: "app");
- `celeryw_bin`: path to the celery binary (default: "/usr/bin/celery")
- `celeryw_daemon_options: extraneous options to be passed _as is_ on
  the celery command line (default: "");
- `celeryw_etc_dir`: path to the directory in which store celery's
  worker(s) configuration files (default: "/etc/celery");
- `celeryw_group`: group under which the celery processes should
  run (default: `{{ansible_user_id}}`)
- `celeryw_log_dir`: path to the directory in which store celery's logs
  files (`/var/log/celery`);
- `celeryw_log_filename`: name to use for the log files. Refer to
  celery's documentation to know more about available template
  substitutions (default: `%n%I.log`);
- `celeryw_log_level`: (default: `ERROR`)
- `celeryw_pid_filename`: `%n.pid`
- `celeryw_queues`: "celery"
- `celeryw_run_dir`: path in which store celery's PID files _etc._
  (default: `/var/run/celery`)
- `celeryw_user`: identity under which the celery processes should
  run (default: `{{ansible_user_id}}`)
- `celeryw_workers`: the variable that contains the list of workers
  to set-up (default: `[]`);


### Variables intended for other roles

None


Dependencies
------------

To have systemd manage for you celery workers, this role depends on the
`cans.systemd-unit-install` role.


Example Playbook
----------------

This first example will configure workers for two applications, relying
mostly on the [default values](#defaults) provided in the role:

```yaml
- hosts: servers
  roles:
     - role: cans.celery-worker
       celeryw_workers:
         - app_name: "mailer"
           app_module: "application.interfaces.tasks.mailer"
         - app_name: "data-cruncher"
           app_module: "application.interfaces.tasks.cruncher"
           app_variable: "cruncher_app"
```

This second example overrides more variables some at a global level,
in the playbook's `vars` section, others at the worker description
level:

```yaml

- hosts: servers
  vars:
     celeryw_bin: "/opt/local/python-virtualenvs/python3.6/bin/celery"
  roles:
     - role: cans.celery-worker
       celeryw_workers:
         - app_name: "mailer"
           app_module: "application.interfaces.tasks.mailer"
         - app_name: "data-cruncher"
           app_module: "application.interfaces.tasks.cruncher"
           app_variable: "cruncher_app"
         - app_name: "legacy-data-cruncher"
           app_module: "legacy.interfaces.tasks.cruncher"
           conf_dir: "/opt/local/etc/celery"
           celery_bin: "/opt/local/python-virtualenvs/python2.5/bin/celery"
```

You may also refer to the playbook found under the `test` directory
for more examples.


License
-------

GPLv2


Author Information
------------------

Copyright © 2017, Nicolas CANIART.
