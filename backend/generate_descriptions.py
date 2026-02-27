"""
Generate detailed movement descriptions for each avatar video using Gemini.
Run once to create sign_descriptions.json.
"""
import os
import sys
import json
import base64
import requests
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / '.env')

API_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = "google/gemini-3-flash-preview"
AVATARS_DIR = Path(__file__).parent / "media" / "avatars"

DESCRIBE_PROMPT = (
    "هذا فيديو لشخص يؤدي إشارة بلغة الإشارة.\n"
    "صِف بالتفصيل الدقيق:\n"
    "- وضع اليدين: مفتوحة/مغلقة/قبضة/أصابع ممدودة\n"
    "- حركة اليدين: الاتجاه (أعلى/أسفل/يمين/يسار/أمام/خلف)، السرعة، التكرار\n"
    "- موضع اليدين بالنسبة للجسم: أمام الوجه/الصدر/البطن/بجانب الرأس\n"
    "- حركة الذراعين والكتفين\n"
    "- أي حركة للرأس أو الجسم مرتبطة بالإشارة\n"
    "- تسلسل الحركات من البداية للنهاية\n"
    "\n"
    "تجاهل تماماً: الملابس، الخلفية، الألوان، الإضاءة.\n"
    "صف الحركات فقط بالعربية بشكل تفصيلي كأنك تكتب تعليمات لشخص يريد تقليد نفس الحركة."
)


def describe_video(video_path: str) -> str:
    api_key = os.getenv("OPENROUTER_API_KEY")
    with open(video_path, 'rb') as f:
        b64 = base64.b64encode(f.read()).decode('ascii')

    ext = video_path.rsplit('.', 1)[-1].lower()
    mime = f"video/{ext}" if ext != 'mov' else 'video/quicktime'

    body = {
        "model": MODEL,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are an expert at describing physical movements and gestures in detail. "
                    "Focus ONLY on body movements, hand shapes, and motion. "
                    "Ignore all visual details like clothing, background, colors. "
                    "Reply in Arabic."
                ),
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": DESCRIBE_PROMPT},
                    {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}},
                ],
            },
        ],
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    print(f"  Calling Gemini API...")
    resp = requests.post(API_URL, headers=headers, json=body, timeout=300)
    data = resp.json()
    return data["choices"][0]["message"]["content"]


def main():
    descriptions = {}

    for f in sorted(AVATARS_DIR.iterdir()):
        if f.suffix.lower() != '.mp4':
            continue
        sign_name = f.stem
        print(f"\nProcessing: {sign_name}")
        desc = describe_video(str(f))
        descriptions[sign_name] = desc
        print(f"  Done: {desc[:80]}...")

    out_path = Path(__file__).parent / "sign_descriptions.json"
    with open(out_path, 'w', encoding='utf-8') as fp:
        json.dump(descriptions, fp, ensure_ascii=False, indent=2)

    print(f"\nSaved {len(descriptions)} descriptions to {out_path}")


if __name__ == '__main__':
    main()
