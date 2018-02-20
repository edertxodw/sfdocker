# Our modules import #
from modules.general import main as general


def console(arguments, exe, container, shell_c, console_path):
    args = general.get_arguments(arguments)
    general.run(exe + ' ' + container + ' ' + shell_c + ' php ' + console_path + args)
