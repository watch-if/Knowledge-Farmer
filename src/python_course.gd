extends RefCounted

const LESSONS := [
	{
		"id": "clean",
		"title": "货架点货",
		"file": "clean_quotes.py",
		"goal": "货架到了两批零件。用 products.csv 生成装车清单。箱名去掉两端空格，价格保留两位小数，保存到 report.csv。",
		"sample": "输入 products.csv\nitem_id,name,price\nA12,  Brass Nut  ,2.5\n\n期望 report.csv\nitem_id,name,price\nA12,Brass Nut,2.50",
		"hints": [
			"在第一关里，row 是一条报价，row['name'] 取出商品名。在这一项末尾加 .strip()，去掉名字两端的空格。",
			"找到 price 这一项。Decimal(row['price']) 读取金额，format(金额, '.2f') 把它变成例如 2.50 的文字。",
			"保留 item_id。name 改成 row['name'].strip()，price 改成 format(Decimal(row['price']), '.2f')。这两项仍要写在 writer.writerow 的花括号里。",
		],
		"starter": """import csv
from decimal import Decimal

fields = ["item_id", "name", "price"]
with open("products.csv", encoding="utf-8", newline="") as source:
    with open("report.csv", "w", encoding="utf-8", newline="") as report:
        writer = csv.DictWriter(report, fieldnames=fields)
        writer.writeheader()
        for row in csv.DictReader(source):
            writer.writerow({
                "item_id": row["item_id"],
                "name": row["name"],  # 在末尾加 .strip()
                "price": row["price"],  # 把价格变成两位小数
            })
""",
		"solution": """import csv
from decimal import Decimal

fields = ["item_id", "name", "price"]
with open("products.csv", encoding="utf-8", newline="") as source:
    with open("report.csv", "w", encoding="utf-8", newline="") as report:
        writer = csv.DictWriter(report, fieldnames=fields)
        writer.writeheader()
        for row in csv.DictReader(source):
            writer.writerow({
                "item_id": row["item_id"],
                "name": row["name"].strip(),
                "price": format(Decimal(row["price"]), ".2f"),
            })
""",
	},
	{
		"id": "catalog",
		"title": "远端目录补货",
		"file": "collect_catalog.py",
		"goal": "调度站更新了目录。从命令行给的 URL 取回网页，提取每只货箱的编号、名称和价格，再生成 report.csv。",
		"sample": "练习页源码：\n<tr data-id=\"B21\"\n    data-name=\"Bolt &amp; Nut\"\n    data-price=\"7.5\"></tr>\n\n期望报表：\nB21,Bolt & Nut,7.50",
		"hints": [
			"urlopen 已经取回网页。现在把注意力放在收到 HTML 标签时会调用的 handle_starttag。",
			"用 dict(attrs) 得到属性字典。只处理含 data-id 的 tr，其余标签直接跳过。",
			"把 data-id、data-name、data-price 映射成 item_id、name、price，组装字典后追加到 self.rows。",
		],
		"starter": """import csv
import sys
from decimal import Decimal
from html.parser import HTMLParser
from urllib.request import urlopen

class Catalog(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows = []

    def handle_starttag(self, tag, attrs):
        # TODO: 从商品 tr 的属性读取编号、名称和价格。
        pass

parser = Catalog()
with urlopen(sys.argv[1], timeout=3) as response:
    parser.feed(response.read().decode("utf-8"))

with open("report.csv", "w", encoding="utf-8", newline="") as report:
    writer = csv.DictWriter(report, fieldnames=["item_id", "name", "price"])
    writer.writeheader()
    writer.writerows(parser.rows)
""",
		"solution": """import csv
import sys
from decimal import Decimal
from html.parser import HTMLParser
from urllib.request import urlopen

class Catalog(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows = []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag != "tr" or "data-id" not in values:
            return
        self.rows.append({
            "item_id": values["data-id"],
            "name": values["data-name"].strip(),
            "price": format(Decimal(values["data-price"]), ".2f"),
        })

parser = Catalog()
with urlopen(sys.argv[1], timeout=3) as response:
    parser.feed(response.read().decode("utf-8"))

with open("report.csv", "w", encoding="utf-8", newline="") as report:
    writer = csv.DictWriter(report, fieldnames=["item_id", "name", "price"])
    writer.writeheader()
    writer.writerows(parser.rows)
""",
	},
]
