"""Run the player's local script against two supplier datasets."""
import csv
import html
import json
import os
import subprocess
import sys
import tempfile
import threading
from contextlib import contextmanager
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from functools import partial

FIELDS = ("item_id", "name", "price")
CASES = (
    (("A12", "  Brass Nut  ", "2.5", "2.50"), ("A18", "Angle, Small", "16", "16.00")),
    (
        ("B21", "Bolt & Nut", "7.5", "7.50"),
        ("B90", 'Steel "Flat"', "0.25", "0.25"),
        ("C08", "垫片", "12.3", "12.30"),
    ),
)


class CatalogHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


@contextmanager
def catalog_url(directory):
    handler = partial(CatalogHandler, directory=directory)
    with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            yield f"http://127.0.0.1:{server.server_port}/catalog.html"
        finally:
            server.shutdown()
            worker.join()


def write_data(lesson, folder, rows):
    if lesson == "clean":
        with (folder / "products.csv").open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(FIELDS)
            writer.writerows(row[:3] for row in rows)
        return

    table = ["<!doctype html><meta charset=utf-8><table><tr><th>Catalog</th></tr>"]
    for item_id, name, price, _ in rows:
        table.append(
            f'<tr data-price="{html.escape(price)}" data-id="{html.escape(item_id)}"'
            f' data-name="{html.escape(name)}"><td>{html.escape(name)}</td></tr>'
        )
    table.append("</table>")
    (folder / "catalog.html").write_text("\n".join(table), encoding="utf-8")


def execute_script(script, folder, *arguments):
    prefix = os.environ.get("FARMER_ANDROID_PYTHON_ARGV")
    python = json.loads(prefix) if prefix else [sys.executable]
    try:
        result = subprocess.run(
            [*python, "-X", "utf8", str(script), *arguments],
            cwd=folder,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=7,
        )
    except subprocess.TimeoutExpired:
        return "脚本超过 7 秒还未结束，请检查是否有循环或网络请求未完成。", ""
    if result.returncode:
        return (result.stderr or result.stdout or "脚本退出时返回错误。")[-1800:], ""
    return "", result.stdout


def grade_case(lesson, script, rows, folder):
    write_data(lesson, folder, rows)
    if lesson == "catalog":
        with catalog_url(folder) as url:
            error, _ = execute_script(script, folder, url)
    else:
        error, _ = execute_script(script, folder)
    if error:
        return error
    report = folder / "report.csv"
    if not report.is_file():
        return "没有生成 report.csv。请检查文件名和保存位置。"
    try:
        with report.open(encoding="utf-8-sig", newline="") as stream:
            reader = csv.DictReader(stream)
            if tuple(reader.fieldnames or ()) != FIELDS:
                return "首行必须是 item_id,name,price。"
            actual = list(reader)
    except (OSError, UnicodeError, csv.Error) as exc:
        return f"无法读取 CSV：{exc}"
    expected = [dict(zip(FIELDS, (item_id, name.strip(), normalized)))
                for item_id, name, _, normalized in rows]
    if len(actual) != len(expected):
        return f"报表应有 {len(expected)} 条报价，实际有 {len(actual)} 条。"
    for index, (found, wanted) in enumerate(zip(actual, expected), 1):
        if found != wanted:
            return f"第 {index} 条报价与预期不符：{found!r}"
    return ""


def grade_warmup(lesson, filename):
    expected = {
        "warmup_print": "准备装车",
        "warmup_edit": "开始备货",
    }[lesson]
    with tempfile.TemporaryDirectory(prefix="farmer-warmup-") as temporary:
        error, output = execute_script(Path(filename).resolve(), temporary)
    if error:
        print(error)
        return 1
    if output.strip() != expected:
        print(f"这次输出：{output.strip() or '（空）'}\n目标输出：{expected}")
        return 1
    print(output.strip())
    return 0


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    lesson, filename = sys.argv[1:]
    if lesson in {"warmup_print", "warmup_edit"}:
        return grade_warmup(lesson, filename)
    if lesson not in {"clean", "catalog"}:
        return 1
    with tempfile.TemporaryDirectory(prefix="farmer-quotes-") as temporary:
        preview = ""
        boxes = []
        for index, rows in enumerate(CASES, 1):
            folder = Path(temporary) / str(index)
            folder.mkdir()
            error = grade_case(lesson, Path(filename).resolve(), rows, folder)
            if error:
                print(f"样例 {index}/{len(CASES)} 未通过\n{error}")
                return 1
            print(f"样例 {index}/{len(CASES)} · 核对 {len(rows)} 条报价")
            if index == 1:
                with (folder / "report.csv").open(encoding="utf-8-sig", newline="") as stream:
                    boxes = list(csv.DictReader(stream))
                preview = (folder / "report.csv").read_text(encoding="utf-8-sig").strip()
    print(f"报表验收通过。\n\n报表预览\n{preview}")
    print(json.dumps(boxes, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
