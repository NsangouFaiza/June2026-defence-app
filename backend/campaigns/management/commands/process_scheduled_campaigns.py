from django.core.management.base import BaseCommand
from campaigns.services import publish_scheduled_campaigns

class Command(BaseCommand):
    help = 'Processes all scheduled campaigns whose delivery dates/times have arrived and publishes them.'

    def handle(self, *args, **options):
        self.stdout.write('Starting process of scheduled campaigns...')
        count = publish_scheduled_campaigns()
        self.stdout.write(self.style.SUCCESS(f'Successfully processed and published {count} scheduled campaigns.'))
