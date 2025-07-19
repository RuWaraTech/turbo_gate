all:
  children:
    manager:
      hosts:
        turbogate-manager:
          ansible_host: "${manager_ip}"  # Will be replaced by Terraform output
          ansible_user: root
          internal_ip: 10.0.1.10
          
    workers:
      hosts:
        turbogate-worker-1:
          ansible_host: "${worker_1_ip}"  # Will be replaced by Terraform output
          ansible_user: root
          internal_ip: 10.0.1.11
          
        turbogate-worker-2:
          ansible_host: "${worker_2_ip}"  # Will be replaced by Terraform output
          ansible_user: root
          internal_ip: 10.0.1.12
          
  vars:
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    ansible_python_interpreter: /usr/bin/python3
    floating_ip: "${floating_ip}"  # Add floating IP to vars