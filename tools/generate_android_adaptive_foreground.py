from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


def _is_close(rgb1: tuple[int, int, int], rgb2: tuple[int, int, int], tol: int) -> bool:
    return (
        abs(rgb1[0] - rgb2[0]) <= tol
        and abs(rgb1[1] - rgb2[1]) <= tol
        and abs(rgb1[2] - rgb2[2]) <= tol
    )


def remove_background_flood_fill(im: Image.Image, tol: int = 12) -> Image.Image:
    """Makes the corner-connected background transparent while preserving internal whites.

    This specifically targets the solid background behind AP-round.png.
    """

    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()

    # Background color sampled from corners.
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    bg = px[corners[0]][:3]

    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    for x, y in corners:
        q.append((x, y))

    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        if visited[y][x]:
            continue
        visited[y][x] = True

        r, g, b, a = px[x, y]
        if a == 0:
            continue
        if not _is_close((r, g, b), bg, tol):
            continue

        # Mark background pixel as transparent.
        px[x, y] = (r, g, b, 0)

        q.append((x - 1, y))
        q.append((x + 1, y))
        q.append((x, y - 1))
        q.append((x, y + 1))

    return rgba


def make_padded_adaptive_foreground(
    src_path: Path,
    dst_path: Path,
    *,
    canvas: int = 1024,
    scale: float = 0.82,
) -> None:
    src = Image.open(src_path)
    cutout = remove_background_flood_fill(src, tol=12)

    # Ensure square before scaling.
    w, h = cutout.size
    s = max(w, h)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.paste(cutout, ((s - w) // 2, (s - h) // 2), cutout)

    art = int(round(canvas * scale))
    art_img = sq.resize((art, art), resample=Image.Resampling.LANCZOS)

    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(art_img, ((canvas - art) // 2, (canvas - art) // 2), art_img)

    dst_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst_path)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    src = root / "assets" / "icons" / "AP-round.png"
    dst = root / "assets" / "icons" / "AP-round-adaptive-foreground.png"

    make_padded_adaptive_foreground(src, dst, canvas=1024, scale=0.82)
    print(f"Wrote {dst}")


if __name__ == "__main__":
    main()
