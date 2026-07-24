import base64
import io
import json
import logging
import os
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

import numpy as np

from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from ultralytics import YOLO

try:
    from PIL import Image as PILImage
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    logging.warning("Pillow not installed — Python texture compression disabled.")

_HERE       = Path(__file__).parent
MODEL_PATH  = str(_HERE / "best (4).pt")
BLENDER_DIR = str(_HERE / "models")
CONF_THRESH = 0.4
IOU_THRESH  = 0.6

MAX_TEX_DIM  = 2048   
JPEG_QUALITY = 82     
GLTFPACK = shutil.which("gltfpack") or os.path.join(os.path.dirname(__file__), "gltfpack.exe")


def _gltfpack_compress(path: Path) -> tuple[int, int]:
    tool = shutil.which("gltfpack") or (GLTFPACK if os.path.isfile(GLTFPACK) else None)
    if not tool:
        return 0, 0

    original_size = path.stat().st_size
    tmp = path.with_suffix(".tmp.glb")
    try:
        r = subprocess.run(
            [tool, "-i", str(path), "-o", str(tmp), "-cc"],
            capture_output=True, text=True, timeout=600,
        )
        if r.returncode == 0 and tmp.exists() and tmp.stat().st_size > 1000:
            new_size = tmp.stat().st_size
            if new_size < original_size:
                shutil.move(str(tmp), str(path))
                logging.info("gltfpack: %s → %s MB", round(original_size/1e6,1), round(new_size/1e6,1))
                return original_size, new_size
    except Exception as exc:
        logging.warning("gltfpack failed: %s", exc)
    finally:
        if tmp.exists():
            try:
                tmp.unlink()
            except OSError:
                pass
    return original_size, original_size


def _python_compress_textures(path: Path) -> tuple[int, int]:
    if not HAS_PIL:
        return path.stat().st_size, path.stat().st_size

    original_size = path.stat().st_size
    try:
        raw = path.read_bytes()

        magic, version, _total = struct.unpack_from("<III", raw, 0)
        if magic != 0x46546C67 or version != 2:
            return original_size, original_size 
        json_len, json_type = struct.unpack_from("<II", raw, 12)
        if json_type != 0x4E4F534A:  
            return original_size, original_size
        gltf = json.loads(raw[20 : 20 + json_len])

        bin_start = 12 + 8 + json_len
        if bin_start >= len(raw):
            return original_size, original_size  # no binary chunk
        bin_len, bin_type = struct.unpack_from("<II", raw, bin_start)
        if bin_type != 0x004E4942:  
            return original_size, original_size
        bin_data = bytearray(raw[bin_start + 8 : bin_start + 8 + bin_len])

        buffer_views = gltf.get("bufferViews", [])
        images       = gltf.get("images", [])
        if not images:
            return original_size, original_size

        updates: dict[int, tuple[bytes, str]] = {}   

        for img in images:
            bv_idx = img.get("bufferView")
            if bv_idx is None:
                continue
            bv = buffer_views[bv_idx]
            if bv.get("buffer", 0) != 0:
                continue  

            byte_off = bv.get("byteOffset", 0)
            byte_len = bv["byteLength"]
            img_bytes = bytes(bin_data[byte_off : byte_off + byte_len])

            try:
                pil = PILImage.open(io.BytesIO(img_bytes))
                has_alpha = pil.mode in ("RGBA", "LA", "PA") or (
                    pil.mode == "P" and "transparency" in pil.info
                )

                w, h = pil.size
                if w > MAX_TEX_DIM or h > MAX_TEX_DIM:
                    scale = MAX_TEX_DIM / max(w, h)
                    pil = pil.resize((int(w * scale), int(h * scale)), PILImage.LANCZOS)

                buf = io.BytesIO()
                if has_alpha:
                    pil = pil.convert("RGBA")
                    pil.save(buf, format="PNG", optimize=True, compress_level=9)
                    mime = "image/png"
                else:
                    pil = pil.convert("RGB")
                    pil.save(buf, format="JPEG", quality=JPEG_QUALITY, optimize=True)
                    mime = "image/jpeg"

                new_bytes = buf.getvalue()
                if len(new_bytes) < len(img_bytes):
                    updates[bv_idx] = (new_bytes, mime)

            except Exception as exc:
                logging.debug("PIL skip image bv=%s: %s", bv_idx, exc)

        if not updates:
            return original_size, original_size

        sorted_bvs = sorted(enumerate(buffer_views), key=lambda x: x[1].get("byteOffset", 0))
        new_bin    = bytearray()
        new_offsets: dict[int, int] = {}

        for bv_idx, bv in sorted_bvs:
            if bv.get("buffer", 0) != 0:
                continue
            pad = (-len(new_bin)) % 4
            new_bin.extend(b"\x00" * pad)
            new_offsets[bv_idx] = len(new_bin)

            if bv_idx in updates:
                chunk, _ = updates[bv_idx]
                new_bin.extend(chunk)
                buffer_views[bv_idx]["byteLength"] = len(chunk)
            else:
                old_off = bv.get("byteOffset", 0)
                old_len = bv["byteLength"]
                new_bin.extend(bin_data[old_off : old_off + old_len])

        for bv_idx, new_off in new_offsets.items():
            buffer_views[bv_idx]["byteOffset"] = new_off
        for bv_idx, (_, mime) in updates.items():
            for img in images:
                if img.get("bufferView") == bv_idx:
                    img["mimeType"] = mime

        if gltf.get("buffers"):
            gltf["buffers"][0]["byteLength"] = len(new_bin)

        new_json = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        new_json += b" " * ((-len(new_json)) % 4)

        new_bin += b"\x00" * ((-len(new_bin)) % 4)

        total_len = 12 + 8 + len(new_json) + 8 + len(new_bin)
        glb = (
            struct.pack("<III", 0x46546C67, 2, total_len)
            + struct.pack("<II", len(new_json), 0x4E4F534A)
            + new_json
            + struct.pack("<II", len(new_bin), 0x004E4942)
            + bytes(new_bin)
        )

        tmp = path.with_suffix(".tmp.glb")
        tmp.write_bytes(glb)
        try:
            path.unlink()  
        except OSError:
            pass
        shutil.move(str(tmp), str(path))

        new_size = path.stat().st_size
        logging.info("PIL compress: %s → %s MB (%s images updated)",
                     round(original_size/1e6, 1), round(new_size/1e6, 1), len(updates))
        return original_size, new_size

    except Exception as exc:
        logging.warning("Python GLB compression error: %s", exc)
        return original_size, original_size


def compress_glb(path: Path) -> dict:
    orig, new = _gltfpack_compress(path)
    method = "gltfpack"

    if orig == 0:   
        orig, new = _python_compress_textures(path)
        method = "python-pil" if HAS_PIL else "none"

    return {
        "original_mb":       round(orig / 1_000_000, 2),
        "compressed_mb":     round(new  / 1_000_000, 2),
        "reduction_percent": round((1 - new / orig) * 100, 1) if orig > 0 else 0,
        "method":            method,
        "compressed":        orig != new,
    }

import asyncio
from contextlib import asynccontextmanager

print(f"Loading model: {MODEL_PATH}")
model = YOLO(MODEL_PATH)
print("Model loaded.")


async def _startup_compress():
    glb_files = list(Path(BLENDER_DIR).rglob("*.glb"))
    large = [p for p in glb_files if p.stat().st_size >= 5_000_000]
    if not large:
        print("[compress] No large GLB files found — skipping.")
        return
    print(f"[compress] Compressing {len(large)} file(s) before serving…")
    for p in large:
        print(f"[compress]   {p.name}  {round(p.stat().st_size/1e6,1)} MB …", flush=True)
        result = await asyncio.to_thread(compress_glb, p)
        print(f"[compress]   → {result['compressed_mb']} MB  "
              f"({result['reduction_percent']}% saved, method={result['method']})", flush=True)
    print("[compress] Done. Server ready.")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await _startup_compress()
    yield                       


app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/models", StaticFiles(directory=BLENDER_DIR), name="models")


@app.get("/compress-all")
async def compress_all():
    glb_files = list(Path(BLENDER_DIR).rglob("*.glb"))
    results = []
    for p in glb_files:
        if p.stat().st_size < 5_000_000:
            continue
        r = await asyncio.to_thread(compress_glb, p)
        r["filename"] = p.name
        results.append(r)
    return {"compressed": results}


@app.post("/upload-glb")
async def upload_glb(file: UploadFile = File(...)):

    from fastapi import HTTPException
    if not (file.filename or "").lower().endswith(".glb"):
        raise HTTPException(status_code=400, detail="Only .glb files are allowed")

    save_path = Path(BLENDER_DIR) / file.filename
    with open(save_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    compression = await asyncio.to_thread(compress_glb, save_path)

    return {
        "filename": file.filename,
        "status":   "uploaded",
        **compression,
    }


def quad_corners(pts: np.ndarray) -> dict:

    s = pts[:, 0] + pts[:, 1]
    d = pts[:, 0] - pts[:, 1]
    return {
        "tl": pts[s.argmin()].tolist(),
        "br": pts[s.argmax()].tolist(),
        "tr": pts[d.argmax()].tolist(),
        "bl": pts[d.argmin()].tolist(),
    }


@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    suffix = Path(file.filename).suffix if file.filename else ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        shutil.copyfileobj(file.file, tmp)
        tmp_path = tmp.name

    try:
        results = model.predict(
            source=tmp_path,
            conf=CONF_THRESH,
            iou=IOU_THRESH,
            verbose=False,
        )[0]
    finally:
        os.unlink(tmp_path)

    has_masks = results.masks is not None and len(results.masks) > 0
    img_h, img_w = results.orig_shape[:2]

    if not has_masks:
        return {
            "is_empty_land": False,
            "confidence": 0.0,
            "status": "non_empty_land",
            "bounds": None,
        }

    best_idx  = int(results.boxes.conf.argmax())
    best_conf = float(results.boxes.conf[best_idx])
    x1, y1, x2, y2 = [round(float(v)) for v in results.boxes.xyxy[best_idx].cpu().numpy()]
    bw = x2 - x1
    bh = y2 - y1

    poly_px  = results.masks.xy[best_idx]                           
    pts_norm = poly_px.astype(float) / np.array([[img_w, img_h]]) 

    corners = quad_corners(pts_norm)

    step         = max(1, len(pts_norm) // 40)
    poly_sampled = pts_norm[::step].tolist()

    return {
        "is_empty_land": True,
        "confidence":    round(best_conf, 4),
        "status":        "empty_land",
        "bounds": {

            "x1":       round(x1 / img_w, 6),
            "y1":       round(y1 / img_h, 6),
            "x2":       round(x2 / img_w, 6),
            "y2":       round(y2 / img_h, 6),
            "width":    round(bw / img_w, 6),
            "height":   round(bh / img_h, 6),
            "center_x": round((x1 + bw / 2) / img_w, 6),
            "center_y": round((y1 + bh / 2) / img_h, 6),

            "corners":  corners,

            "polygon":  poly_sampled,
        },
    }
