# Imports #
import os
import json
import ConfigParser
# Our modules import #
import generate_config

MESSAGES = json.load(open('messages.json'))

CONFIG_FILE_FOLDER = 'app/deps/conf'
CONFIG_FILE_PATH = CONFIG_FILE_FOLDER + '/sfdocker.conf'

config_parser = ConfigParser.ConfigParser()


def restart_config():
    if os.path.isfile(CONFIG_FILE_PATH):
        with open(CONFIG_FILE_PATH, 'w') as file:
            file.write('')
        set_configuration()


def is_config_file_empty():
    config_parser.read(CONFIG_FILE_PATH)
    if not os.path.isfile(CONFIG_FILE_PATH):
        return True
    elif os.stat(CONFIG_FILE_PATH).st_size == 0:
        return True

    return False


def set_configuration():
    sfdocker_symfony_version = ''
    sfdocker_default_container = ''
    sfdocker_default_user = ''

    while sfdocker_symfony_version == '':
        selected_version = generate_config.choose_version()
        if selected_version:
            sfdocker_symfony_version = selected_version

    while sfdocker_default_container == '':
        sfdocker_default_container = generate_config.choose_container()

    while sfdocker_default_user == '':
        sfdocker_default_user = generate_config.choose_user()

    if not os.path.exists(CONFIG_FILE_FOLDER):
        os.makedirs(CONFIG_FILE_FOLDER)

    with open(CONFIG_FILE_PATH, 'w') as file:
        file.write('[default]\n')
        file.write('sfdocker_symfony_version: ' + sfdocker_symfony_version + '\n')
        file.write('sfdocker_default_container: ' + sfdocker_default_container + '\n')
        file.write('sfdocker_default_user: ' + sfdocker_default_user)


def read_config_file():
    config_parser.read(CONFIG_FILE_PATH)

    return [
        config_parser.get('default', 'sfdocker_symfony_version'),
        config_parser.get('default', 'sfdocker_default_container'),
        config_parser.get('default', 'sfdocker_default_user'),
    ]
