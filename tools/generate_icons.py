"""Generate the app's geometric TV mark. Requires Pillow; no downloaded artwork."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def icon(size: int) -> Image.Image:
    image = Image.new("RGB", (1024, 1024), "#20372f")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((178, 244, 846, 700), radius=100, outline="#d3efdc", width=44)
    draw.line((405, 793, 619, 793), fill="#d3efdc", width=40)
    draw.line((512, 700, 512, 793), fill="#d3efdc", width=40)
    draw.ellipse((460, 418, 564, 522), fill="#d3efdc")
    return image.resize((size, size), Image.Resampling.LANCZOS)


for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    icon(size).save(ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png")

folder = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for entry in json.loads((folder / "Contents.json").read_text())["images"]:
    if "filename" in entry:
        size = round(float(entry["size"].split("x")[0]) * float(entry["scale"].rstrip("x")))
        icon(size).save(folder / entry["filename"])

icon(512).save(ROOT / "docs/icon.png")
