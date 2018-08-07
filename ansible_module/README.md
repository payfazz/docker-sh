# `docker_sh` ansible module

## How to install

Download `docker_sh.py` to your ansible library path

    curl -sSLf https://raw.githubusercontent.com/payfazz/docker-sh/master/ansible_module/docker_sh.py > "$ANSIBLE_LIBRARY/docker_sh.py"

## How to use

Docs from module source code
```
options:
    path:
        description:
            - path to entry point file
        required: true
    recreate_on_new_opts:
        description:
            - recreate container if options is different from current container
        required: false
        default: false
    recreate_on_new_image:
        description:
            - recreate container if image is different from current container
        required: false
        default: false
    force_recreate:
        description:
            - force to recreate container
        required: false
        default: false
```

example playbook:
```yaml
- hosts: all
  gather_facts: False
  become: True
  tasks:
  - name: sync nginx folder
    synchronize: src=nginx dest=/container_state archive=no recursive=yes use_ssh_args=yes
  - name: run nginx
    docker_sh: path=/container_state/nginx/app
```
