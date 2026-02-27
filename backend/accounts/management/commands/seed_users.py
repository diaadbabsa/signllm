from django.core.management.base import BaseCommand
from accounts.models import User


class Command(BaseCommand):
    help = 'Create default admin and test student accounts'

    def handle(self, *args, **options):
        # Admin account
        if not User.objects.filter(username='admin').exists():
            User.objects.create_superuser(
                username='admin',
                password='admin123',
                full_name='مدير النظام',
                role='admin',
                school_name='الإدارة',
            )
            self.stdout.write(self.style.SUCCESS('Created admin: admin / admin123'))
        else:
            self.stdout.write('Admin already exists, skipping.')

        # Test student account
        if not User.objects.filter(username='student1').exists():
            User.objects.create_user(
                username='student1',
                password='student123',
                full_name='أحمد الطالب',
                role='student',
                school_name='مدرسة النور',
            )
            self.stdout.write(self.style.SUCCESS('Created student: student1 / student123'))
        else:
            self.stdout.write('Student already exists, skipping.')

        self.stdout.write(self.style.SUCCESS('Done!'))
