import argparse
import json
import os
from pathlib import Path

import cv2
import numpy as np
from ultralytics import YOLO

MODEL_PATH  = str(Path(__file__).parent / "best (4).pt")
CONF_THRESH = 0.4
IOU_THRESH  = 0.6
OUTPUT_DIR  = str(Path(__file__).parent / "output")



def run_detection(image_path: str, model: YOLO, conf: float, iou: float):
    results = model.predict(
        source=image_path,
        conf=conf,
        iou=iou,
        verbose=False,
    )
    return results[0]


def build_app_json(image_name: str, result) -> dict:
    """
    JSON 1 — for the NLP / application layer.

    Schema:
    {
        "image": "filename.jpg",
        "is_empty_land": true | false,
        "confidence": 0.0 - 1.0,
        "detection_count": int,
        "status": "empty_land" | "non_empty_land"
    }
    """
    has_masks = result.masks is not None and len(result.masks) > 0

    if not has_masks:
        return {
            "image":           image_name,
            "is_empty_land":   False,
            "confidence":      0.0,
            "detection_count": 0,
            "status":          "non_empty_land"
        }

    best_conf = float(result.boxes.conf.max())

    return {
        "image":           image_name,
        "is_empty_land":   True,
        "confidence":      round(best_conf, 4),
        "detection_count": len(result.masks),
        "status":          "empty_land"
    }


def build_blender_json(image_name: str, result) -> dict:
    """
    JSON 2 — for Blender (polygon + bounding box coordinates).

    Each detection provides:
      - bounding_box        : pixel + normalized x1,y1,x2,y2
      - polygon             : list of [x, y] pixel points of the segmentation mask
      - polygon_normalized  : list of [x, y] normalized 0.0-1.0 points
      - area_pixels         : area of the polygon in pixels
      - area_percentage     : area as % of total image

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
                "area_pixels": float,
                "area_percentage": float,
                "bounding_box": {
                    "pixel":      { "x1", "y1", "x2", "y2", "width", "height", "center_x", "center_y" },
                    "normalized": { "x1", "y1", "x2", "y2", "width", "height", "center_x", "center_y" }
                },
                "polygon":            [[x, y], ...],
                "polygon_normalized": [[x, y], ...],
                "polygon_points": int
            }
        ]
    }
    """
    img_h, img_w = result.orig_shape[:2]
    has_masks    = result.masks is not None and len(result.masks) > 0

    boundaries = []

    if has_masks:
        polygons = result.masks.xy
        boxes    = result.boxes
        confs    = boxes.conf.cpu().numpy()
        cls_ids  = boxes.cls.cpu().numpy()

        for i, (polygon, conf_val, cls_id) in enumerate(zip(polygons, confs, cls_ids)):

            polygon_px   = [[round(float(x), 2), round(float(y), 2)]
                            for x, y in polygon.tolist()]
            polygon_norm = [[round(float(x) / img_w, 6), round(float(y) / img_h, 6)]
                            for x, y in polygon.tolist()]

            poly_arr = np.array(polygon_px, dtype=np.float32)
            area_px  = float(cv2.contourArea(poly_arr)) if len(poly_arr) >= 3 else 0.0
            area_pct = round(area_px / (img_w * img_h) * 100, 4)

            x1, y1, x2, y2 = [round(float(v)) for v in boxes.xyxy[i].cpu().numpy()]
            bw = x2 - x1
            bh = y2 - y1
            cx = x1 + bw // 2
            cy = y1 + bh // 2

            boundaries.append({
                "id":              i,
                "confidence":      round(float(conf_val), 4),
                "label":           result.names[int(cls_id)],
                "area_pixels":     round(area_px, 2),
                "area_percentage": area_pct,
                "bounding_box": {
                    "pixel": {
                        "x1": x1, "y1": y1,
                        "x2": x2, "y2": y2,
                        "width":    bw,
                        "height":   bh,
                        "center_x": cx,
                        "center_y": cy,
                    },
                    "normalized": {
                        "x1":      round(x1 / img_w, 6),
                        "y1":      round(y1 / img_h, 6),
                        "x2":      round(x2 / img_w, 6),
                        "y2":      round(y2 / img_h, 6),
                        "width":   round(bw / img_w, 6),
                        "height":  round(bh / img_h, 6),
                        "center_x": round(cx / img_w, 6),
                        "center_y": round(cy / img_h, 6),
                    }
                },
                "polygon":            polygon_px,
                "polygon_normalized": polygon_norm,
                "polygon_points":     len(polygon_px),
            })

    return {
        "image":        image_name,
        "image_width":  img_w,
        "image_height": img_h,
        "boundaries":   boundaries,
    }

def save_visualization(result, blender_data: dict, viz_path: str):
    img      = result.orig_img.copy()
    img_h, img_w = img.shape[:2]
    boundaries   = blender_data.get("boundaries", [])

    for b in boundaries:
        conf  = b["confidence"]
        label = f"{b['label']} {conf:.2f}"

        poly_pts = np.array(b["polygon"], dtype=np.int32)
        if len(poly_pts) >= 3:
            overlay = img.copy()
            cv2.fillPoly(overlay, [poly_pts], color=(0, 255, 136))
            img = cv2.addWeighted(overlay, 0.35, img, 0.65, 0)
            cv2.polylines(img, [poly_pts], isClosed=True, color=(0, 255, 136), thickness=2)

        p = b["bounding_box"]["pixel"]
        x1, y1, x2, y2 = p["x1"], p["y1"], p["x2"], p["y2"]
        cv2.rectangle(img, (x1, y1), (x2, y2), (0, 255, 0), 2)

        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.75, 2)
        cv2.rectangle(img, (x1, y1 - th - 10), (x1 + tw + 6, y1), (0, 255, 0), -1)
        cv2.putText(img, label, (x1 + 3, y1 - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.75, (0, 0, 0), 2)

    if not boundaries:
        cv2.putText(img, "No empty land detected",
                    (20, img_h - 20), cv2.FONT_HERSHEY_SIMPLEX,
                    1.0, (0, 0, 255), 2)

    cv2.imwrite(viz_path, img)

def process_image(image_path: str, model: YOLO, output_dir: str, conf: float, iou: float):
    """Process a single image and write all 3 output files."""
    image_name = Path(image_path).name
    stem       = Path(image_path).stem

    result       = run_detection(image_path, model, conf, iou)
    app_data     = build_app_json(image_name, result)
    blender_data = build_blender_json(image_name, result)

    app_path     = os.path.join(output_dir, f"{stem}_app.json")
    blender_path = os.path.join(output_dir, f"{stem}_blender.json")
    viz_path     = os.path.join(output_dir, f"{stem}_viz.jpg")

    with open(app_path, "w") as f:
        json.dump(app_data, f, indent=2)

    with open(blender_path, "w") as f:
        json.dump(blender_data, f, indent=2)

    save_visualization(result, blender_data, viz_path)

    status = "EMPTY LAND" if app_data["is_empty_land"] else "NON-EMPTY"
    print(f"[{status}]  {image_name}  "
          f"(conf: {app_data['confidence']}  detections: {app_data['detection_count']})  "
          f"→  {stem}_app.json  |  {stem}_blender.json  |  {stem}_viz.jpg")

    return app_data, blender_data


def process_batch(folder: str, model: YOLO, output_dir: str, conf: float, iou: float):
    exts   = {".jpg", ".jpeg", ".png", ".bmp", ".tiff", ".webp"}
    images = [str(p) for p in Path(folder).iterdir() if p.suffix.lower() in exts]

    if not images:
        print(f"No images found in: {folder}")
        return

    all_app     = []
    all_blender = []

    for img_path in sorted(images):
        app_data, blender_data = process_image(img_path, model, output_dir, conf, iou)
        all_app.append(app_data)
        all_blender.append(blender_data)

    with open(os.path.join(output_dir, "batch_app.json"), "w") as f:
        json.dump(all_app, f, indent=2)

    with open(os.path.join(output_dir, "batch_blender.json"), "w") as f:
        json.dump(all_blender, f, indent=2)

    empty_count = sum(1 for d in all_app if d["is_empty_land"])
    print(f"\nDone. Processed {len(images)} images.")
    print(f"  Empty land : {empty_count}")
    print(f"  Not empty  : {len(images) - empty_count}")
    print(f"Combined files → batch_app.json  |  batch_blender.json")


def main():
    parser = argparse.ArgumentParser(description="Land detection — segmentation model")
    group  = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--image",  help="Path to a single image")
    group.add_argument("--folder", help="Path to a folder of images")
    parser.add_argument("--output", default=OUTPUT_DIR,  help="Output directory")
    parser.add_argument("--conf",   type=float, default=CONF_THRESH, help="Confidence threshold")
    parser.add_argument("--iou",    type=float, default=IOU_THRESH,  help="IoU threshold")
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)

    print(f"Loading model  : {MODEL_PATH}")
    print(f"Conf threshold : {args.conf}")
    print(f"IoU  threshold : {args.iou}")
    print(f"Output folder  : {args.output}\n")

    model = YOLO(MODEL_PATH)

    if args.image:
        process_image(args.image, model, args.output, args.conf, args.iou)
    else:
        process_batch(args.folder, model, args.output, args.conf, args.iou)


if __name__ == "__main__":
    main()