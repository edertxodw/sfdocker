# Imports #
import sys
import os
# Our modules import #
import modules.colors as colors
from modules.config import main as config


def run(command):
    os.system(command)


def get_arguments(args):
    arguments = ''

    for i, arg in enumerate(args):
        if i > 1:
            arguments += str(' ' + arg)

    return arguments


def no_args():
    print colors.ERROR + config.MESSAGES['no_args'] + colors.ENDC
    sys.exit(0)
