# 加载 PLIP 生成的 PyMOL 会话文件
load ./plip_out/COMPLEX_PROTEIN_UNL_A_1.pse

# 基础显示
show labels, Interactions

# 残基
python
from pymol import cmd
from collections import OrderedDict

report_path = "./plip_out/complex_report.txt"

def parse_residues_from_plip_report(path):
	"""
	从 PLIP 的 complex_report.txt 表格行中提取 RESNR/RESCHAIN。
	返回: OrderedDict({chain: [resi1, resi2, ...]})
	"""
	chain_to_resi = OrderedDict()
	with open(path, "r", encoding="utf-8", errors="ignore") as f:
		for line in f:
			# 数据行示例：
			# | 16 | LEU | A | ...
			if not line.lstrip().startswith("|"):
				continue
			cols = [c.strip() for c in line.split("|")]
			# split 后典型格式: ['', '16', 'LEU', 'A', ... , '']
			if len(cols) < 4:
				continue
			if not cols[1].isdigit():
				continue
			resi = cols[1]
			chain = cols[3] if cols[3] else ""
			chain_to_resi.setdefault(chain, [])
			if resi not in chain_to_resi[chain]:
				chain_to_resi[chain].append(resi)
	return chain_to_resi

chain_map = parse_residues_from_plip_report(report_path)

if not chain_map:
	raise RuntimeError(f"未在 {report_path} 中解析到 RESNR 数据")

if len(chain_map) == 1:
	only_chain = next(iter(chain_map.keys()))
	resi_expr = "+".join(chain_map[only_chain])
	if only_chain:
		sel_expr = f"chain {only_chain} and resi {resi_expr}"
	else:
		sel_expr = f"resi {resi_expr}"
else:
	parts = []
	for ch, resi_list in chain_map.items():
		one = "+".join(resi_list)
		if ch:
			parts.append(f"(chain {ch} and resi {one})")
		else:
			parts.append(f"(resi {one})")
	sel_expr = " or ".join(parts)

cmd.select("myres", sel_expr)
print("Auto selection:", sel_expr)
python end

label (name CA+C1*+C1' and byres myres), "%s-%s" % (resn, resi)

# 输出高分辨率截图
ray 2000,1500
png ../interactions, dpi=300

# 保存会话文件
save ../interactions.pse

quit
