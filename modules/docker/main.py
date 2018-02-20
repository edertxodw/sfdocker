# Our modules import #
from modules.general import main as general


def start(compose):
    general.run(compose + ' start')


def stop(compose):
    general.run(compose + ' stop')


def build(compose):
    general.run(compose + ' up -d --build')


def create(compose):
    general.run(compose + ' up -d')


def restart(compose):
    general.run(compose + ' restart')


def ps(compose):
    general.run(compose + ' ps')
