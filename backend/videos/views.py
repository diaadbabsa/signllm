from urllib.parse import quote

from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages as django_messages

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response

from .models import SignAvatar
from .utils import analyze_video, find_avatar, describe_video, rebuild_descriptions_json


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def analyze_view(request):
    """
    POST /api/videos/analyze/
    Multipart form: video file + optional prompt text.
    Two-step analysis:
      1. Gemini describes the movements
      2. Gemini matches against reference descriptions
    Returns: { "result": "...", "description": "...", "avatar_url": ... }
    """
    if 'video' not in request.FILES:
        return Response(
            {'error': 'لم يتم إرسال ملف فيديو'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    video_file = request.FILES['video']
    video_bytes = video_file.read()
    filename = video_file.name or 'video.mp4'
    prompt = request.data.get('prompt', '')

    try:
        analysis = analyze_video(video_bytes, filename, prompt)

        avatar_filename = find_avatar(analysis.get("matched_sign"))
        avatar_url = None
        if avatar_filename:
            encoded_name = quote(avatar_filename)
            avatar_url = request.build_absolute_uri(
                f'/media/avatars/{encoded_name}'
            )

        return Response({
            'result': analysis['result'],
            'description': analysis['description'],
            'matched_sign': analysis.get('matched_sign'),
            'avatar_url': avatar_url,
        })
    except ValueError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except RuntimeError as e:
        return Response({'error': str(e)}, status=status.HTTP_502_BAD_GATEWAY)
    except Exception as e:
        return Response(
            {'error': f'خطأ غير متوقع: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


# ── Admin Panel Views ────────────────────────────────────────────

def avatar_list(request):
    avatars = SignAvatar.objects.all()
    return render(request, 'videos/avatar_list.html', {'avatars': avatars})


def avatar_upload(request):
    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        video_file = request.FILES.get('video')

        if not name:
            django_messages.error(request, 'يرجى إدخال اسم الإشارة')
            return render(request, 'videos/avatar_upload.html')

        if not video_file:
            django_messages.error(request, 'يرجى اختيار ملف فيديو')
            return render(request, 'videos/avatar_upload.html')

        if SignAvatar.objects.filter(name=name).exists():
            django_messages.error(request, f'الإشارة "{name}" موجودة بالفعل')
            return render(request, 'videos/avatar_upload.html')

        video_bytes = video_file.read()
        video_file.seek(0)

        django_messages.info(request, 'جارٍ تحليل الفيديو بالذكاء الاصطناعي...')

        try:
            description = describe_video(video_bytes, video_file.name or 'video.mp4')
        except Exception as e:
            django_messages.error(request, f'فشل تحليل الفيديو: {e}')
            return render(request, 'videos/avatar_upload.html')

        avatar = SignAvatar(name=name, description=description)
        avatar.video.save(f'{name}.mp4', video_file, save=True)

        rebuild_descriptions_json()

        django_messages.success(request, f'تم رفع الإشارة "{name}" بنجاح')
        return redirect('avatar_list')

    return render(request, 'videos/avatar_upload.html')


def avatar_delete(request, pk):
    if request.method == 'POST':
        avatar = get_object_or_404(SignAvatar, pk=pk)
        name = avatar.name
        if avatar.video:
            avatar.video.delete(save=False)
        avatar.delete()
        rebuild_descriptions_json()
        django_messages.success(request, f'تم حذف الإشارة "{name}"')
    return redirect('avatar_list')
