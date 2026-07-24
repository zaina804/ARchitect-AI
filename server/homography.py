"""
HOMOGRAPHY TEST SCRIPT
======================
1. Put your land image in the same folder as this file
2. Update IMAGE_PATH below to your image filename
3. Run: python homography.py
4. Copy the OUTPUT JSON at the bottom
5. Paste it into test.html where it says PASTE_CAMERA_POSE_HERE
"""

import cv2
import numpy as np
import json

# ════════════════════════════════════════
#  CHANGE THESE TWO THINGS ONLY
# ════════════════════════════════════════

IMAGE_PATH = "1742980183_11787597-fa33-46ff-afdc-3e787be814f2_cleanup.jpeg"   # ← your land photo filename

# Your AI model JSON output — paste yours here
AI_JSON = {
  "image": "1742980183_11787597-fa33-46ff-afdc-3e787be814f2_cleanup.jpeg",
  "image_width": 800,
  "image_height": 600,
  "boundaries": [
    {
      "id": 0,
      "confidence": 0.7218,
      "label": "empty_land",
      "pixel": {
        "x1": 4,
        "y1": 223,
        "x2": 808,
        "y2": 629,
        "width": 804,
        "height": 406,
        "center_x": 406,
        "center_y": 426
      },
      "normalized": {
        "x1": 0.005,
        "y1": 0.371667,
        "x2": 1.01,
        "y2": 1.048333,
        "width": 1.005,
        "height": 0.676667,
        "center_x": 0.5075,
        "center_y": 0.71
      }
    }
  ]
}

# ════════════════════════════════════════
#  HOMOGRAPHY CODE — do not change below
# ════════════════════════════════════════

def order_corners(pts):
    pts  = pts.reshape(4, 2).astype(np.float32)
    rect = np.zeros((4, 2), dtype=np.float32)
    s    = pts.sum(axis=1)
    diff = np.diff(pts, axis=1).flatten()
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]
    return rect


def detect_land_corners(image, bbox_pixel):
    x1 = int(bbox_pixel['x1'])
    y1 = int(bbox_pixel['y1'])
    x2 = int(bbox_pixel['x2'])
    y2 = int(bbox_pixel['y2'])

    h_img, w_img = image.shape[:2]
    x1 = max(0, x1); y1 = max(0, y1)
    x2 = min(w_img, x2); y2 = min(h_img, y2)

    fallback = np.array([
        [x1, y1], [x2, y1], [x2, y2], [x1, y2]
    ], dtype=np.float32)

    try:
        crop = image[y1:y2, x1:x2]
        if crop.size == 0:
            return order_corners(fallback)

        gray  = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        blur  = cv2.GaussianBlur(gray, (7, 7), 0)
        edges = cv2.Canny(blur, 30, 120)
        kernel = np.ones((3, 3), np.uint8)
        edges  = cv2.dilate(edges, kernel, iterations=1)

        contours, _ = cv2.findContours(
            edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
        )
        if not contours:
            return order_corners(fallback)

        largest = max(contours, key=cv2.contourArea)
        peri    = cv2.arcLength(largest, True)
        approx  = cv2.approxPolyDP(largest, 0.02 * peri, True)

        if len(approx) != 4:
            hull   = cv2.convexHull(largest)
            peri   = cv2.arcLength(hull, True)
            approx = cv2.approxPolyDP(hull, 0.04 * peri, True)

        if len(approx) == 4:
            corners = approx.reshape(4, 2).astype(np.float32)
            corners[:, 0] += x1
            corners[:, 1] += y1
            return order_corners(corners)

        return order_corners(fallback)

    except Exception as e:
        print(f'Corner detection error: {e} — using bbox fallback')
        return order_corners(fallback)


def calculate_camera_pose(image_corners, image_width, image_height,
                           land_width_m=15.0, land_depth_m=10.0):
    world_points = np.array([
        [0,            0, 0           ],
        [land_width_m, 0, 0           ],
        [land_width_m, 0, land_depth_m],
        [0,            0, land_depth_m],
    ], dtype=np.float32)

    focal_length  = image_width * 1.2
    camera_matrix = np.array([
        [focal_length, 0,            image_width  / 2.0],
        [0,            focal_length, image_height / 2.0],
        [0,            0,            1                 ],
    ], dtype=np.float32)

    dist_coeffs  = np.zeros((4, 1), dtype=np.float32)
    image_points = image_corners.astype(np.float32)

    success, rotation_vec, translation_vec = cv2.solvePnP(
        world_points, image_points,
        camera_matrix, dist_coeffs,
        flags=cv2.SOLVEPNP_ITERATIVE
    )

    if not success:
        print('solvePnP failed — using fallback pose')
        return None

    rotation_mat, _ = cv2.Rodrigues(rotation_vec)
    cam_pos = (-rotation_mat.T @ translation_vec).flatten()

    sy    = np.sqrt(rotation_mat[0,0]**2 + rotation_mat[1,0]**2)
    pitch = float(np.arctan2(-rotation_mat[2,0], sy))
    yaw   = float(np.arctan2( rotation_mat[1,0], rotation_mat[0,0]))
    roll  = float(np.arctan2( rotation_mat[2,1], rotation_mat[2,2]))

    fov_h = float(2 * np.arctan(image_width  / (2*focal_length)) * 180/np.pi)
    fov_v = float(2 * np.arctan(image_height / (2*focal_length)) * 180/np.pi)

    projected, _ = cv2.projectPoints(
        world_points, rotation_vec, translation_vec,
        camera_matrix, dist_coeffs
    )
    error = float(np.mean(np.linalg.norm(
        projected.reshape(4,2) - image_points, axis=1
    )))

    land_center = np.array([land_width_m/2, 0, land_depth_m/2])
    distance    = float(np.linalg.norm(cam_pos - land_center))

    return {
        'camera_x': float(cam_pos[0]),
        'camera_y': float(cam_pos[1]),
        'camera_z': float(cam_pos[2]),
        'pitch':    pitch,
        'yaw':      yaw,
        'roll':     roll,
        'distance': distance,
        'fov_horizontal': fov_h,
        'fov_vertical':   fov_v,
        'target_x': float(land_center[0]),
        'target_y': 0.0,
        'target_z': float(land_center[2]),
        'reprojection_error': error,
        'reliable': error < 20.0,
    }


def run():
    print('═' * 50)
    print(' HOMOGRAPHY PIPELINE')
    print('═' * 50)

    # Load image
    image = cv2.imread(IMAGE_PATH)
    if image is None:
        print(f'\n⚠ Could not load image: {IMAGE_PATH}')
        print('  Using a blank image for testing...')
        # Use blank image with correct dimensions from AI JSON
        w = AI_JSON.get('image_width',  800)
        h = AI_JSON.get('image_height', 600)
        image = np.zeros((h, w, 3), dtype=np.uint8)

    h, w = image.shape[:2]
    print(f'\n✓ Image loaded: {w}x{h}')

    # Parse AI JSON
    land       = AI_JSON['boundaries'][0]
    confidence = land['confidence']
    label      = land['label']
    print(f'✓ AI result: {label} (confidence: {confidence:.1%})')

    # Detect corners
    print('\nDetecting land corners...')
    corners_px = detect_land_corners(image, land['pixel'])
    print(f'✓ Corners (pixels):')
    labels = ['top-left', 'top-right', 'bottom-right', 'bottom-left']
    for i, (label_name, corner) in enumerate(zip(labels, corners_px)):
        print(f'  {label_name}: ({corner[0]:.0f}, {corner[1]:.0f})')

    # Normalize corners
    corners_norm = [
        {'x': float(p[0]/w), 'y': float(p[1]/h)}
        for p in corners_px
    ]

    # Calculate camera pose
    print('\nCalculating camera pose...')
    pose = calculate_camera_pose(corners_px, w, h)

    if pose:
        print(f'✓ Camera position: x={pose["camera_x"]:.2f}  y={pose["camera_y"]:.2f}  z={pose["camera_z"]:.2f}')
        print(f'✓ Camera angles:   pitch={pose["pitch"]:.3f}  yaw={pose["yaw"]:.3f}')
        print(f'✓ Distance:        {pose["distance"]:.2f}m from land center')
        print(f'✓ Field of view:   {pose["fov_vertical"]:.1f}°')
        print(f'✓ Error:           {pose["reprojection_error"]:.2f}px  reliable={pose["reliable"]}')
    else:
        print('⚠ solvePnP failed — using fallback pose')
        pose = {
            'camera_x': 0.0,  'camera_y': 8.0,  'camera_z': 12.0,
            'pitch': -0.5,    'yaw': 0.0,        'roll': 0.0,
            'distance': 14.0,
            'fov_horizontal': 60.0, 'fov_vertical': 45.0,
            'target_x': 7.5,  'target_y': 0.0,  'target_z': 5.0,
            'reprojection_error': 999, 'reliable': False,
        }

    # Build final result
    result = {
        'valid':       True,
        'confidence':  confidence,
        'land_bounds': land['normalized'],
        'land_corners': corners_norm,
        'camera_pose': pose,
    }

    # ── OUTPUT ──
    output_json = json.dumps(result, indent=2)

    print('\n' + '═' * 50)
    print(' OUTPUT — COPY THIS INTO test.html')
    print('═' * 50)
    print(output_json)

    # Also save to a file so you can easily copy it
    with open('homography_output.json', 'w') as f:
        f.write(output_json)
    print('\n✓ Also saved to: homography_output.json')
    print('\nNext step: open test.html and paste this JSON')
    print('where it says: PASTE_CAMERA_POSE_HERE')
    print('═' * 50)


run()