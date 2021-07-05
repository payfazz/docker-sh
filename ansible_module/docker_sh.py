DOCUMENTATION = '''
---
module: docker_sh

description: Manage running docker container using docker-sh (https://github.com/payfazz/docker-sh.git)

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

author:
    - Kurnia D Win (win@payfazz.com)
'''

EXAMPLES = '''
- name: sync nginx folder
  synchronize: src=nginx dest=/container_state archive=no recursive=yes use_ssh_args=yes
- name: run nginx application
  docker_sh: path=/container_state/nginx/app
'''

from ansible.module_utils.basic import AnsibleModule
import os
import subprocess

def main():
    module = AnsibleModule(
        argument_spec=dict(
            path=dict(type='str', required=True),
            recreate_on_new_opts=dict(type='bool', required=False, default=False),
            recreate_on_new_image=dict(type='bool', required=False, default=False),
            force_recreate=dict(type='bool', required=False, default=False)
        )
    )
    path = module.params['path']
    recreate_on_new_opts = module.params['recreate_on_new_opts']
    recreate_on_new_image = module.params['recreate_on_new_image']
    force_recreate = module.params['force_recreate']
    result = dict(
        changed=False
    )

    if not(os.path.isfile(path) and os.access(path, os.X_OK)):
        module.fail_json(msg="cannot execute: " + path, **result)

    def run_command(cmd):
        proc = subprocess.Popen([path, cmd],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate()
        if proc.returncode != 0:
            module.fail_json(msg="failed when executing '" + cmd + "' command: (" + str(proc.returncode) + ") " + err, **result)
        return out

    status_list = run_command("status").strip().split()

    no_container = "no_container" in status_list
    running = "running" in status_list
    not_running = "not_running" in status_list
    different_opts = "different_opts" in status_list
    different_image = "different_image" in status_list

    if no_container or not_running:
        result["changed"] = True
        run_command("start")

    elif (different_opts and recreate_on_new_opts) or (different_image and recreate_on_new_image) or force_recreate:
        result["changed"] = True
        run_command("stop")
        run_command("rm")
        run_command("start")

    module.exit_json(**result)

if __name__ == '__main__':
    main()
