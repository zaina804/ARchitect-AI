"""
Land Detection Script
---------------------
Uses the trained YOLO model to determine if an image contains empty land or not.

Outputs TWO JSON files per image (or batch):
  1. app_result.json   → for the NLP/application layer (is the land empty or not)
  2. blender_result.json → for Blender (bounding box coordinates of detected land boundaries)

Usage:
    python detect_land.py --image path/to/image.jpg
    python detect_land.py --folder path/to/folder/
    python detect_land.py --folder "C:/Users/zaina/Downloads/complete"
"""

import argparse
import json
import os
from pathlib import Path

import cv2
from ultralytics import YOLO

# ── Config ────────────────────────────────────────────────────────────────────
MODEL_PATH  = str(Path(__file__).parent / "best (4).pt")
CONF_THRESH = 0.1    # minimum confidence to count a detection
OUTPUT_DIR  = str(Path(__file__).parent / "output")
# ─────────────────────────────────────────────────────────────────────────────


def run_detection(image_path: str, model: YOLO) -> dict:
    """Run YOLO inference on a single image and return raw results."""
    results = model.predict(source=image_path, conf=CONF_THRESH, verbose=False)
    return results[0]


def build_app_json(image_name: str, result) -> dict:
    """
    JSON 1 – for the NLP / application layer.

    Schema:
    {
        "image": "filename.jpg",
        "is_empty_land": true | false,
        "confidence": 0.0 – 1.0,   # highest-confidence detection, 0.0 if none
        "detection_count": int,
        "status": "empty_land" | "non_empty_land"
    }
    """
    detections = result.obb if result.obb is not None else result.boxes
    if detections is None or len(detections.conf) == 0:
        return {
            "image": image_name,
            "is_empty_land": False,
            "confidence": 0.0,
            "detection_count": 0,
            "status": "non_empty_land"
        }

    best_conf = float(detections.conf.max())

    return {
        "image": image_name,
        "is_empty_land": True,
        "confidence": round(best_conf, 4),
        "detection_count": 1,
        "status": "empty_land"
    }


def build_blender_json(image_name: str, result) -> dict:
    """
    JSON 2 – for Blender (land boundary coordinates).

    Each bounding box is provided in two formats:
      - normalized  : values 0.0–1.0 relative to image size (portable)
      - pixel       : absolute pixel coordinates (x1, y1, x2, y2)

    Schema:
    {
        "image": "filename.jpg",
        "image_width": int,
        "image_height": int,
        "boundaries": [
            {
                "id": 0,
                "confidence": 0.95,
                "label": "empty_land",
                "pixel": {
                    "x1": int, "y1": int,
                    "x2": int, "y2": int,
                    "width": int, "height": int,
                    "center_x": int, "center_y": int
                },
                "normalized": {
                    "x1": float, "y1": float,
                    "x2": float, "y2": float,
                    "width": float, "height": float,
                    "center_x": float, "center_y": float
                }
            },
            ...
        ]
    }
    """
    img_h, img_w = result.orig_shape[:2]
    detections = result.obb if result.obb is not None else result.boxes

    boundaries = []
    if detections is not None and len(detections.conf) > 0:
        # Keep only the single most-confident detection
        best_idx = int(detections.conf.argmax())
        indices = [best_idx]
        for i in indices:
            x1, y1, x2, y2 = [round(v) for v in detections.xyxy[i].tolist()]
            conf  = round(float(detections.conf[i]), 4)
            label = result.names[int(detections.cls[i])]

            bw = x2 - x1
            bh = y2 - y1
            cx = x1 + bw // 2
            cy = y1 + bh // 2

            boundaries.append({
                "id":         i,
                "confidence": conf,
                "label": label,
                "pixel": {
                    "x1": x1, "y1": y1,
                    "x2": x2, "y2": y2,
                    "width": bw, "height": bh,
                    "center_x": cx, "center_y": cy
                },
                "normalized": {
                    "x1": round(x1 / img_w, 6),
                    "y1": round(y1 / img_h, 6),
                    "x2": round(x2 / img_w, 6),
                    "y2": round(y2 / img_h, 6),
                    "width":    round(bw / img_w, 6),
                    "height":   round(bh / img_h, 6),
                    "center_x": round(cx / img_w, 6),
                    "center_y": round(cy / img_h, 6)
                }
            })

    return {
        "image": image_name,
        "image_width":  img_w,
        "image_height": img_h,
        "boundaries":   boundaries
    }


def process_image(image_path: str, model: YOLO, output_dir: str):
    image_name = Path(image_path).name
    stem       = Path(image_path).stem

    result      = run_detection(image_path, model)
    app_data    = build_app_json(image_name, result)
    blender_data = build_blender_json(image_name, result)

    app_path     = os.path.join(output_dir, f"{stem}_app.json")
    blender_path = os.path.join(output_dir, f"{stem}_blender.json")

    with open(app_path, "w") as f:
        json.dump(app_data, f, indent=2)

    with open(blender_path, "w") as f:
        json.dump(blender_data, f, indent=2)

    # Save visualization with bounding box drawn
    viz_path = os.path.join(output_dir, f"{stem}_viz.jpg")
    save_visualization(result, blender_data, viz_path)

    status = "EMPTY LAND" if app_data["is_empty_land"] else "NON-EMPTY"
    print(f"[{status}]  {image_name}  (conf: {app_data['confidence']})  →  {stem}_app.json  |  {stem}_blender.json  |  {stem}_viz.jpg")

    return app_data, blender_data


def save_visualization(result, blender_data: dict, viz_path: str):
    img = result.orig_img.copy()
    boundaries = blender_data.get("boundaries", [])

    for b in boundaries:
        p = b["pixel"]
        x1, y1, x2, y2 = p["x1"], p["y1"], p["x2"], p["y2"]
        conf = b["confidence"]

        # Draw bounding box
        cv2.rectangle(img, (x1, y1), (x2, y2), (0, 255, 0), 3)

        # Draw label
        label = f"{b['label']} {conf:.2f}"
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.8, 2)
        cv2.rectangle(img, (x1, y1 - th - 8), (x1 + tw + 4, y1), (0, 255, 0), -1)
        cv2.putText(img, label, (x1 + 2, y1 - 4), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 0), 2)

    cv2.imwrite(viz_path, img)


def process_batch(folder: str, model: YOLO, output_dir: str):
    """Process all images in a folder and also write combined JSON files."""
    exts = {".jpg", ".jpeg", ".png", ".bmp", ".tiff", ".webp"}
    images = [str(p) for p in Path(folder).iterdir() if p.suffix.lower() in exts]

    if not images:
        print(f"No images found in {folder}")
        return

    all_app     = []
    all_blender = []

    for img_path in sorted(images):
        app_data, blender_data = process_image(img_path, model, output_dir)
        all_app.append(app_data)
        all_blender.append(blender_data)

    # Combined files (useful when sending a batch to the NLP model or Blender)
    with open(os.path.join(output_dir, "batch_app.json"), "w") as f:
        json.dump(all_app, f, indent=2)

    with open(os.path.join(output_dir, "batch_blender.json"), "w") as f:
        json.dump(all_blender, f, indent=2)

    print(f"\nDone. Processed {len(images)} images.")
    print(f"Combined files → batch_app.json | batch_blender.json")


def main():
    parser = argparse.ArgumentParser(description="Land detection — outputs app + blender JSONs")
    group  = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--image",  help="Path to a single image")
    group.add_argument("--folder", help="Path to a folder of images")
    parser.add_argument("--output", default=OUTPUT_DIR, help="Output directory for JSON files")
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)

    print(f"Loading model: {MODEL_PATH}")
    model = YOLO(MODEL_PATH)

    if args.image:
        process_image(args.image, model, args.output)
    else:
        process_batch(args.folder, model, args.output)


if __name__ == "__main__":
    main()
