all:
  children:
    swarm_managers:
      hosts:
        turbogate-manager:
          ansible_host: "${manager_ip}"
          ansible_user: "${ssh_user}"
          internal_ip: 10.0.1.10
    workers:
      hosts:
        turbogate-worker-1:
          ansible_host: "${worker_1_ip}"
          ansible_user: "${ssh_user}"
          internal_ip: 10.0.1.11
        turbogate-worker-2:
          ansible_host: "${worker_2_ip}"
          ansible_user: "${ssh_user}"
          internal_ip: 10.0.1.12
    bastion:
      hosts:
        turbogate-bastion:
          ansible_host: "${bastion_ip}"
          ansible_user: "${ssh_user}"
  vars:
    ansible_ssh_common_args: >-
      -o StrictHostKeyChecking=no
      %{ if bastion_ip != "" }
      -o ProxyJump=${ssh_user}@${bastion_ip}
      %{ endif }
    ansible_python_interpreter: /usr/bin/python3
    floating_ip: "${floating_ip}"
