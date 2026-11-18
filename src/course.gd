extends RefCounted

const LESSONS := [
	{
		"id": "equation", "file": "Equation", "title": "读懂等式", "symbol": "addTwo",
		"task": "证明自然数 2 + 3 等于 5。把等号两边当作 Lean 要核对的同一个值。",
		"goal": "addTwo : (2 : Nat) + 3 = 5",
		"contract": "theorem zetaVerified : (2 : Nat) + 3 = 5 := addTwo",
		"starter": "theorem addTwo : (2 : Nat) + 3 = 5 := by\n  sorry\n",
		"solution": "theorem addTwo : (2 : Nat) + 3 = 5 := by\n  rfl\n",
		"hints": ["等号两边计算后分别是多少？", "Lean 的 rfl 可用于两边能化成同一值的等式。", "把 sorry 换成 rfl，然后检查。"],
		"diagram": "2 + 3 = 5\n● ●  +  ● ● ●  =  ● ● ● ● ●",
		"skill": "等式与 rfl", "action": "试算台",
	},
	{
		"id": "accumulate", "file": "Accumulation", "title": "有限累加", "symbol": "oddTotal",
		"task": "用 def 定义前 n 个奇数的和。零项为 0，每增一项就加入 2 * n + 1。",
		"goal": "oddTotal 0 = 0\noddTotal (n + 1) = oddTotal n + (2 * n + 1)",
		"contract": "theorem zetaVerified : oddTotal 0 = 0 ∧ (∀ n : Nat, oddTotal (n + 1) = oddTotal n + (2 * n + 1)) := by\n  constructor\n  · rfl\n  · intro n\n    rfl",
		"starter": "def oddTotal : Nat → Nat\n  | 0 => 0\n  | n + 1 => sorry\n\n#eval oddTotal 4\n",
		"solution": "def oddTotal : Nat → Nat\n  | 0 => 0\n  | n + 1 => oddTotal n + (2 * n + 1)\n\n#eval oddTotal 4\n",
		"hints": ["算完前 n 项后，下一项是哪个奇数？", "用 oddTotal n 代表之前的累加结果。", "把 sorry 换成 oddTotal n + (2 * n + 1)。"],
		"diagram": "0 → 1 → 4 → 9 → 16\n     +1   +3   +5   +7",
		"skill": "def 与递归", "action": "试算台",
	},
	{
		"id": "odds", "file": "OddTotal", "title": "归纳证明 · 奇数和", "symbol": "oddTotal_sq",
		"task": "证明前 n 个奇数的和等于 n²。先展开定义，再用归纳假设改写。",
		"goal": "n : Nat\nih : oddTotal n = n * n\n⊢ oddTotal (n + 1) = (n + 1) * (n + 1)",
		"contract": "theorem zetaVerified : ∀ n : Nat, oddTotal n = n * n := oddTotal_sq",
		"starter": "import Accumulation\n\ntheorem oddTotal_sq (n : Nat) : oddTotal n = n * n := by\n  induction n with\n  | zero => rfl\n  | succ n ih =>\n    calc\n      oddTotal (n + 1) = oddTotal n + (2 * n + 1) := by rfl\n      _ = n * n + (2 * n + 1) := by sorry\n      _ = (n + 1) * (n + 1) := by sorry\n",
		"solution": "import Accumulation\n\ntheorem oddTotal_sq (n : Nat) : oddTotal n = n * n := by\n  induction n with\n  | zero => rfl\n  | succ n ih =>\n    calc\n      oddTotal (n + 1) = oddTotal n + (2 * n + 1) := by rfl\n      _ = n * n + (2 * n + 1) := by rw [ih]\n      _ = (n + 1) * (n + 1) := by\n        simp only [Nat.add_mul, Nat.mul_add, Nat.mul_one, Nat.one_mul]\n        omega\n",
		"hints": ["归纳假设 ih 告诉你 oddTotal n 等于什么？", "第二步可用 rw [ih]。第三步要用乘法分配律展开平方。", "用 simp only [Nat.add_mul, Nat.mul_add, Nat.mul_one, Nat.one_mul] 展开平方，再用 omega 整理线性项。"],
		"diagram": "■ ■ □\n■ ■ □    2² + 5 = 3²\n□ □ □    添一圈的格子数是 2n + 1",
		"skill": "归纳法与 calc", "action": "证明台",
	},
	{
		"id": "reuse", "file": "Difference", "title": "复用定理 · 改写两项", "symbol": "oddDiff",
		"task": "把两个奇数部分和的差改写成平方差。调用自己证过的 oddTotal_sq。",
		"goal": "n m : Nat\n⊢ oddTotal n - oddTotal m = n * n - m * m",
		"contract": "theorem zetaVerified : ∀ n m : Nat, oddTotal n - oddTotal m = n * n - m * m := oddDiff",
		"starter": "import OddTotal\n\ntheorem oddDiff (n m : Nat) :\n    oddTotal n - oddTotal m =\n      n * n - m * m := by\n  sorry\n",
		"solution": "import OddTotal\n\ntheorem oddDiff (n m : Nat) :\n    oddTotal n - oddTotal m =\n      n * n - m * m := by\n  rw [oddTotal_sq n, oddTotal_sq m]\n",
		"hints": ["等号左边有哪两个子式能用奇数和定理？", "oddTotal_sq n 和 oddTotal_sq m 分别处理两个位置。", "用 rw [oddTotal_sq n, oddTotal_sq m] 完成两次改写。"],
		"diagram": "oddTotal n − oddTotal m\n↓\nn² − oddTotal m\n↓\nn² − m²",
		"skill": "调用与 rw", "action": "改写台",
	},
]

const ROADMAP := [
	["入门与有限和", "读懂等式", "有限累加", "归纳法", "复用定理"],
	["数学分析", "极限与单调有界", "构造 e 与指数函数", "级数与尾项估计", "积分与一致收敛"],
	["基础分支", "同余与有限群", "Dirichlet 特征标", "全纯与留数", "亚纯延拓与零点"],
	["解析数论", "ζ 与 Dirichlet L", "Mellin 与 Poisson", "Eisenstein 整数与 Hecke L", "大筛与三次 theta 系数"],
	["论文挑战", "11/12 无零点区域", "参数与关键估计", "7/8 准黎曼猜想"],
]
