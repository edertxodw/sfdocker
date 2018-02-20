# Our modules import #
import main
from modules import colors


def error_message():
    print
    print colors.ERROR + main.MESSAGES['symfony_version']['invalid_option'] + colors.ENDC
    print


def choose_version():
    try:
        response = int(raw_input(main.MESSAGES['symfony_version']['question']))
        if (response == 2) or (response == 3) or (response == 4):
            return str(response)
        else:
            error_message()
    except ValueError:
        error_message()


def choose_container():
    return str(raw_input(main.MESSAGES['default_container']['question']))


def choose_user():
    return str(raw_input(main.MESSAGES['default_user']['question']))
