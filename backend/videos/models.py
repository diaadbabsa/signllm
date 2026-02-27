from django.db import models


class SignAvatar(models.Model):
    name = models.CharField(max_length=200, unique=True, verbose_name='اسم الإشارة')
    video = models.FileField(upload_to='avatars/', verbose_name='فيديو الأفاتار')
    description = models.TextField(blank=True, verbose_name='وصف الحركات')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'إشارة أفاتار'
        verbose_name_plural = 'إشارات الأفاتار'

    def __str__(self):
        return self.name
