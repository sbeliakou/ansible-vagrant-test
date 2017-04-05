from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.plugins.callback import CallbackBase
from termcolor import colored
import json

class CallbackModule(CallbackBase):

    '''
    This is the default callback interface, which simply prints messages
    to stdout when new callback events are received.
    '''

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'stdout'
    CALLBACK_NAME = 'output'

    def playbook_on_stats(self, stats):
        pass

    def playbook_on_play_start(self, name):
        caption = "PLAY: {}".format(name)
        print("\n" + caption + " " + "*"*(80 - len(caption)))

    def playbook_on_task_start(self, name, is_conditional):
        caption = "Task: {0}".format(name)
        print("\n" + caption + " " + "."*(80 - len(caption)))

    def v2_playbook_on_include(self, included_file):
        print("including: {0}".format(included_file))

    def v2_playbook_on_stats(self, stats):
        self.playbook_on_stats(stats)

    def v2_playbook_on_play_start(self, play):
        self.playbook_on_play_start(play.name)

    def v2_playbook_on_task_start(self, task, is_conditional):
        # print(task.__dict__)
        if "{0}".format(task.name) != "":
            # if task._role != None:
            #     name = "{0} | {1}".format(task._role, task.name)
            self.playbook_on_task_start(task.name, is_conditional)
        else:
            self.playbook_on_task_start(task._attributes["action"], is_conditional)

    def v2_runner_on_failed(self, result, ignore_errors=False):
        color = 'red'
        host = result._host
        module_name = result._result["invocation"]["module_name"]

        result._result.pop("invocation", None)

        if module_name == "vagrant":
            module_stderr = result._result.get("module_stderr", "")
            module_stdout = result._result.get("module_stdout", "")
            print(colored("failed: [{0}]".format(host), color))
            print(colored("STDERR: " + module_stderr, color))
            print(colored("STDOUT: " + module_stdout, color))

            if result._result.get("_ansible_parsed", False):
                print("Ansible Reason: failed to parse")

        else:
            print(colored("failed: [{0}]".format(host) + json.dumps(result._result, indent=4), color))

    def v2_runner_on_ok(self, result):
        host = result._host
        module_name = result._result["invocation"]["module_name"]
        color = 'green'
        if not result._result["_ansible_no_log"]:
            if module_name != "setup":
                changed = "changed" if result._result["changed"] else "ok"
                color = "yellow" if result._result["changed"] else "green"

                res = result._result
                res.pop("invocation", None)
                res.pop("changed", None)
                res.pop("_ansible_parsed", None)
                res.pop("_ansible_no_log", None)
                res.pop("_ansible_verbose_always", None)

                report = "{0}: [{1}] => module: '{2}', result: {3}".format(changed, host, module_name, json.dumps(res, indent=4))
            else:
                color = "green"
                report = "{0}: [{1}]".format("ok", host)
            text = colored(report, color)
            print(text)

    def v2_runner_on_skipped(self, result):
        if C.DISPLAY_SKIPPED_HOSTS:
            print("failed: " + result._result.__dict__)

    def v2_runner_on_unreachable(self, result):
        host = result._host.get_name()
        self.runner_on_unreachable(host, result._result)

