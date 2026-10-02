from django.apps import AppConfig
from django.db.models.signals import post_migrate


def auto_seed_data(sender, **kwargs):
    if sender.name == 'users':
        from django.core.management import call_command
        try:
            call_command('seed_data')
        except Exception:
            pass


class UsersConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'users'

    def ready(self):
        post_migrate.connect(auto_seed_data, sender=self)
