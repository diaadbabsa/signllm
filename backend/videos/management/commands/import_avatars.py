"""Import existing avatar videos and descriptions into SignAvatar model."""
import json
from pathlib import Path
from django.core.management.base import BaseCommand
from django.core.files import File
from videos.models import SignAvatar


class Command(BaseCommand):
    help = 'Import existing avatar videos and descriptions into the database'

    def handle(self, *args, **options):
        base = Path(__file__).resolve().parent.parent.parent.parent
        desc_path = base / 'sign_descriptions.json'
        avatars_dir = base / 'media' / 'avatars'

        if not desc_path.exists():
            self.stderr.write('sign_descriptions.json not found')
            return

        with open(desc_path, 'r', encoding='utf-8') as f:
            descriptions = json.load(f)

        count = 0
        for name, description in descriptions.items():
            video_file = avatars_dir / f'{name}.mp4'
            if not video_file.exists():
                self.stderr.write(f'Video not found: {video_file}')
                continue

            obj, created = SignAvatar.objects.update_or_create(
                name=name,
                defaults={'description': description},
            )

            if not obj.video or created:
                with open(video_file, 'rb') as vf:
                    obj.video.save(f'{name}.mp4', File(vf), save=True)

            status = 'created' if created else 'updated'
            self.stdout.write(f'{status}: {name}')
            count += 1

        self.stdout.write(self.style.SUCCESS(f'Imported {count} avatars'))
