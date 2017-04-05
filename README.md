# Usage examples: 

```bash
$ ansible-playbook playbook.yml -vv --tags=start,stop,destroy
$ ansible-playbook playbook.yml -vv --tags=start,tests,stop,destroy
$ ansible-playbook playbook.yml -vv --tags=start,stop,destroy
$ ansible-playbook playbook.yml -vv --tags=start,tests,destroy
$ ansible-playbook playbook.yml -vv --tags=start,tests
$ ansible-playbook playbook.yml -vv --tags=destroy
```