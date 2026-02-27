"""
Two-step video analysis:
  Step 1 – Gemini describes the movements in the uploaded video.
  Step 2 – Gemini compares that description against pre-generated
           reference descriptions and picks the closest match.
"""
import os
import json
import base64
import requests
from pathlib import Path

API_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = "google/gemini-3-flash-preview"
MAX_FILE_SIZE_MB = 20

MIME_MAP = {
    "mp4": "video/mp4",
    "webm": "video/webm",
    "ogg": "video/ogg",
    "mov": "video/quicktime",
    "avi": "video/x-msvideo",
    "mkv": "video/x-matroska",
}

DESCRIPTIONS_PATH = Path(__file__).resolve().parent.parent / "sign_descriptions.json"

DESCRIBE_PROMPT = (
    "هذا فيديو صامت بدون صوت لشخص يؤدي حركات بيديه وجسمه.\n"
    "صِف بالتفصيل الدقيق:\n"
    "- وضع اليدين: مفتوحة/مغلقة/قبضة/أصابع ممدودة\n"
    "- حركة اليدين: الاتجاه (أعلى/أسفل/يمين/يسار/أمام/خلف)، السرعة، التكرار\n"
    "- موضع اليدين بالنسبة للجسم: أمام الوجه/الصدر/البطن/بجانب الرأس\n"
    "- حركة الذراعين والكتفين\n"
    "- أي حركة للرأس أو الجسم مرتبطة بالإشارة\n"
    "- تسلسل الحركات من البداية للنهاية\n"
    "\n"
    "تجاهل تماماً: الملابس، الخلفية، الألوان، الإضاءة، وأي صوت في الفيديو.\n"
    "لا تستخدم الصوت أبداً في تحليلك حتى لو كان موجوداً. اعتمد فقط على ما تراه بصرياً.\n"
    "صف الحركات فقط بالعربية بشكل تفصيلي."
)


def _api_key():
    key = os.getenv("OPENROUTER_API_KEY")
    if not key:
        raise RuntimeError("OPENROUTER_API_KEY not set")
    return key


def _headers():
    return {
        "Authorization": f"Bearer {_api_key()}",
        "Content-Type": "application/json",
    }


def _parse(resp):
    raw = resp.content
    for enc in ("utf-8", "cp1256", "latin1"):
        try:
            return json.loads(raw.decode(enc))
        except Exception:
            continue
    return resp.json()


def _load_reference_descriptions() -> dict[str, str]:
    if not DESCRIPTIONS_PATH.exists():
        return {}
    with open(DESCRIPTIONS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def _call_gemini(messages: list, timeout: int = 300) -> str:
    body = {"model": MODEL, "messages": messages}
    resp = requests.post(API_URL, headers=_headers(), json=body, timeout=timeout)
    if resp.status_code >= 400:
        err = resp.content.decode("utf-8", errors="replace")
        raise RuntimeError(f"API error {resp.status_code}: {err[:500]}")
    data = _parse(resp)
    try:
        return data["choices"][0]["message"]["content"]
    except (KeyError, IndexError):
        raise RuntimeError(f"Unexpected API response: {json.dumps(data)[:500]}")


# ── Step 1: Describe the uploaded video ──────────────────────────

def describe_video(video_bytes: bytes, filename: str) -> str:
    size_mb = len(video_bytes) / (1024 * 1024)
    if size_mb > MAX_FILE_SIZE_MB:
        raise ValueError(
            f"الملف كبير جداً ({size_mb:.1f} MB). الحد الأقصى {MAX_FILE_SIZE_MB} MB."
        )

    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "mp4"
    mime = MIME_MAP.get(ext, "video/mp4")
    b64 = base64.b64encode(video_bytes).decode("ascii")
    data_url = f"data:{mime};base64,{b64}"

    messages = [
        {
            "role": "system",
            "content": (
                "You are an expert at describing physical movements and gestures in videos. "
                "Focus ONLY on hand shapes, hand movements, arm positions, and body gestures. "
                "COMPLETELY IGNORE any audio/sound in the video. Do NOT use audio for your analysis at all. "
                "IGNORE clothing, background, objects, colors, lighting, face details. "
                "Reply in Arabic with a detailed description of the movements."
            ),
        },
        {
            "role": "user",
            "content": [
                {"type": "text", "text": DESCRIBE_PROMPT},
                {"type": "image_url", "image_url": {"url": data_url}},
            ],
        },
    ]

    return _call_gemini(messages)


# ── Step 2: Match description against references ────────────────

def match_description(video_description: str) -> tuple[str | None, str]:
    """
    Returns (matched_sign_name_or_None, explanation_text).
    """
    refs = _load_reference_descriptions()
    if not refs:
        return None, video_description

    ref_block = ""
    for i, (name, desc) in enumerate(refs.items(), 1):
        ref_block += f"\n--- إشارة رقم {i}: {name} ---\n{desc}\n"

    match_prompt = (
        "أنت خبير في لغة الإشارة. لديك وصف لحركات شخص في فيديو، "
        "ولديك مرجع بأوصاف إشارات معروفة.\n\n"
        "== وصف الفيديو المرسل ==\n"
        f"{video_description}\n\n"
        "== أوصاف الإشارات المرجعية ==\n"
        f"{ref_block}\n\n"
        "المطلوب:\n"
        "1. قارن وصف الفيديو المرسل مع كل إشارة مرجعية.\n"
        "2. حدد أقرب إشارة تتطابق مع الحركات الموصوفة.\n"
        "3. اشرح لماذا هذه الإشارة هي الأقرب (أوجه التشابه في الحركات).\n"
        "4. إذا لم تتطابق مع أي إشارة بشكل معقول، قل ذلك.\n\n"
        "أجب بالصيغة التالية بالضبط:\n"
        "الإشارة: [اسم الإشارة أو 'غير معروفة']\n"
        "التوضيح: [شرحك]\n"
    )

    messages = [
        {
            "role": "system",
            "content": (
                "You are a sign language matching expert. "
                "You compare movement descriptions and find the closest match. "
                "Reply in Arabic. Follow the exact response format requested."
            ),
        },
        {"role": "user", "content": match_prompt},
    ]

    result = _call_gemini(messages, timeout=120)

    matched_name = None
    for name in refs:
        if name in result:
            matched_name = name
            break

    return matched_name, result


# ── Main entry point ─────────────────────────────────────────────

def analyze_video(video_bytes: bytes, filename: str, prompt: str = "") -> dict:
    """
    Returns {
        "description": "...",   # Step 1 output
        "result": "...",        # Step 2 matching output
        "matched_sign": "..."   # Sign name or None
    }
    """
    description = describe_video(video_bytes, filename)
    matched_sign, match_result = match_description(description)

    return {
        "description": description,
        "result": match_result,
        "matched_sign": matched_sign,
    }


def find_avatar(matched_sign: str | None) -> str | None:
    if not matched_sign:
        return None
    from .models import SignAvatar
    try:
        avatar = SignAvatar.objects.get(name=matched_sign)
        if avatar.video:
            return avatar.video.name.split('/')[-1]
    except SignAvatar.DoesNotExist:
        pass

    avatars_dir = Path(__file__).resolve().parent.parent / "media" / "avatars"
    if not avatars_dir.exists():
        return None
    for f in avatars_dir.iterdir():
        if f.suffix.lower() == '.mp4' and f.stem == matched_sign:
            return f.name
    return None


def rebuild_descriptions_json():
    """Rebuild sign_descriptions.json from all SignAvatar records in the database."""
    from .models import SignAvatar
    descriptions = {}
    for avatar in SignAvatar.objects.all():
        if avatar.description:
            descriptions[avatar.name] = avatar.description
    with open(DESCRIPTIONS_PATH, "w", encoding="utf-8") as f:
        json.dump(descriptions, f, ensure_ascii=False, indent=2)
