extends RefCounted

const BASIC_STATION_COUNT := 3

const LESSONS := [
	{
		"id": "label",
		"title": "贴名牌 · 变量",
		"file": "print_label.py",
		"goal": "名牌机需要打印货物的名字。第一行已经把名字放进变量 name。修改第二行，让脚本读取 name 里的值。货物会变，名牌要跟着变。",
		"first_action": "运行一次，看脚本印出了什么。再对照提示改第 2 行。",
		"sample": "订单里的 name\nBrass Nut\n\n目标输出\nBrass Nut",
		"hints": [
			"变量是给一个值起的名字。print(\"name\") 照着引号打印四个字母。想打印变量里的内容，去掉引号。",
			"保留第一行，把第二行改成 print(name)，然后运行脚本。",
		],
		"starter": """from order import name
print("name")
""",
		"solution": """from order import name
print(name)
""",
	},
	{
		"id": "normalize",
		"title": "清理名牌 · 字典与文字",
		"file": "trim_label.py",
		"goal": "这次一条订单放在 row 中。row 是一个字典，每个值都有一个键。row[\"name\"] 取出商品名。让名牌只保留名字，去掉文字前后的空格。",
		"first_action": "在 row[\"name\"] 后面加 .strip()，再运行脚本。",
		"sample": "来货名称（引号标出边界）\n\"  Brass Nut  \"\n\n目标输出\nBrass Nut",
		"hints": [
			"先用 row[\"name\"] 取出名字，再调用文字的 .strip() 去掉两端空格。名字中间的空格会保留。",
			"把第二行改成 print(row[\"name\"].strip())，然后运行脚本。",
		],
		"starter": """from order import row
print(row["name"])
""",
		"solution": """from order import row
print(row["name"].strip())
""",
	},
	{
		"id": "loop",
		"title": "批量贴签 · for 循环",
		"file": "print_batch.py",
		"goal": "rows 是装着多条订单的列表。rows[0] 只拿到第一条。用 for 从列表逐条取出订单，依次打印每个商品名，每个名字各占一行。",
		"first_action": "先运行看只打印第一条，再点「订单与提示」练习 for。",
		"sample": "订单里的两个名称\nBrass Nut\nAngle, Small\n\n目标输出\nBrass Nut\nAngle, Small",
		"hints": [
			"for row in rows: 每次取出一条订单并命名为 row。冒号后的缩进行，就是每次重复执行的指令。",
			"去掉原先的 print 行，写 for row in rows:。下一行先敲四个空格，再写 print(row[\"name\"].strip())。",
		],
		"starter": """from order import rows

print(rows[0]["name"].strip())
""",
		"solution": """from order import rows

for row in rows:
    print(row["name"].strip())
""",
	},
	{
		"id": "clean",
		"title": "货架点货",
		"file": "clean_quotes.py",
		"goal": "货架到了两批零件。用 products.csv 生成装车清单。箱名去掉两端空格，价格保留两位小数，保存到 report.csv。",
		"first_action": "从 name 和 price 两行改起，其他代码会读取和写出 CSV。",
		"sample": "输入 products.csv\nitem_id,name,price\nA12,  Brass Nut  ,2.5\n\n期望 report.csv\nitem_id,name,price\nA12,Brass Nut,2.50",
		"hints": [
			"for 循环每次读入一条 CSV 报价，把它叫作 row。和名牌练习一样，在 row['name'] 后加 .strip()。",
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
		"first_action": "先看订单里的目录样例，再补 name 和 price 两项。",
		"sample": "练习页源码：\n<tr data-id=\"B21\"\n    data-name=\"Bolt &amp; Nut\"\n    data-price=\"7.5\"></tr>\n\n期望报表：\nB21,Bolt & Nut,7.50",
		"hints": [
			"urlopen 取回网页，handle_starttag 每读到一个 HTML 标签就执行一次。tr 表示表格的一行，data-id 是货物编号。",
			"values 是属性字典，像上一站的 row。用 values['data-name'].strip() 取干净的名字。",
			"name 写 values['data-name'].strip()，price 写 format(Decimal(values['data-price']), '.2f')。如果草稿还用 pass，先补上提示中的字典读取。",
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
        values = dict(attrs)
        if tag != "tr" or "data-id" not in values:
            return
        self.rows.append({
            "item_id": values["data-id"],
            "name": "",  # 从 values 读取名字
            "price": "",  # 从 values 读取并格式化价格
        })

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
