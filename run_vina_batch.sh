#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)


PAIR_FILE=${PAIR_FILE:-$SCRIPT_DIR/pairs.tsv}
OUT_ROOT=${OUT_ROOT:-$SCRIPT_DIR/docking_results}
VINA_EXHAUSTIVENESS=${VINA_EXHAUSTIVENESS:-32}
CLEAN_PML=${CLEAN_PML:-/home/data/cq/pcw/1.pipeline/vina/pml/clean_receptor.pml}
BOX_PML=${BOX_PML:-/home/data/cq/pcw/1.pipeline/vina/pml/box.pml}
COMPLEX_PML=${COMPLEX_PML:-/home/data/cq/pcw/1.pipeline/vina/pml/complex.pml}
VISUALIZE_PML=${VISUALIZE_PML:-/home/data/cq/pcw/1.pipeline/vina/pml/visualize.pml}
BOX_INDEX=${BOX_INDEX:-1}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --box)
      BOX_INDEX="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--box N]"
      exit 1
      ;;
  esac
done

if [[ ! "$BOX_INDEX" =~ ^[0-9]+$ ]] || [[ "$BOX_INDEX" -lt 1 ]]; then
  echo "ERROR: --box must be a positive integer, got: $BOX_INDEX"
  exit 1
fi

DEFAULT_POCKET_FILE="./receptor_clean_out/pockets/pocket${BOX_INDEX}_atm.pdb"
DEFAULT_POCKET_OBJ="p${BOX_INDEX}"
POCKET_FILE=${POCKET_FILE:-$DEFAULT_POCKET_FILE}
POCKET_OBJ=${POCKET_OBJ:-$DEFAULT_POCKET_OBJ}

if [[ ! -f "$PAIR_FILE" ]]; then
  echo "ERROR: pair file not found: $PAIR_FILE"
  exit 1
fi

mkdir -p "$OUT_ROOT"

read_vec3() {
  local file="$1"
  if [[ ! -s "$file" ]]; then
    return 1
  fi
  # 兼容 "10 10 10"、"10,10,10"、多行等格式
  local vals
  vals=$(grep -Eo '[-+]?[0-9]*\.?[0-9]+' "$file" | head -n 3 | tr '\n' ' ')
  # shellcheck disable=SC2206
  local arr=($vals)
  if [[ ${#arr[@]} -ne 3 ]]; then
    return 1
  fi
  echo "${arr[0]} ${arr[1]} ${arr[2]}"
}

sanitize_name() {
  echo "$1" | sed 's#[^A-Za-z0-9._-]#_#g'
}

run_one_pair() {
  local receptor_id="$1"
  local receptor_pdb="$2"
  local ligand_id="$3"
  local smiles="$4"

  receptor_id=$(sanitize_name "$receptor_id")
  ligand_id=$(sanitize_name "$ligand_id")

  local job_dir="$OUT_ROOT/${receptor_id}_${ligand_id}/vina_out"
  mkdir -p "$job_dir"

  cp "$receptor_pdb" "$job_dir/receptor.pdb"

  pushd "$job_dir" >/dev/null

  echo "=== [$receptor_id / $ligand_id] 受体预处理 ==="
  # reduce -BUILD -quiet receptor.pdb > receptorH.pdb 

  # 外部 PyMOL 脚本负责清理受体并输出 receptor_clean.pdb
  # pymol -cq /home/data/cq/pcw/1.pipeline/vina/pml/clean_receptor.pml

  # 运行 reduce
  reduce -BUILD -quiet receptor.pdb > receptorH.pdb || echo "reduce failed"
  # 检查 receptorH.pdb 是否存在
  if [ -f receptorH.pdb ]; then
      echo "receptorH.pdb 已生成，继续执行 PyMOL"
      pymol -cq $CLEAN_PML
  else
      echo "receptorH.pdb 未生成，停止流程"
      exit 1
  fi

  echo "=== [$receptor_id / $ligand_id] 口袋预测 ==="
  fpocket -f receptor_clean.pdb
  POCKET_FILE="$POCKET_FILE" POCKET_OBJ="$POCKET_OBJ" pymol -cq "$BOX_PML"

  echo "=== [$receptor_id / $ligand_id] 受体盒子准备 ==="
  BOX_SIZE=$(read_vec3 box_size.txt)
  BOX_CENTER=$(read_vec3 box_center.txt)

  mk_prepare_receptor.py -i receptor_clean.pdb -o vina_receptor -p -v \
    --box_size $BOX_SIZE \
    --box_center $BOX_CENTER

  echo "=== [$receptor_id / $ligand_id] 配体准备 ==="
  scrub.py "$smiles" -o ligand.sdf
  mk_prepare_ligand.py -i ligand.sdf -o vina_ligand.pdbqt

  echo "=== [$receptor_id / $ligand_id] 开始对接 ==="
    local dock_log="docking.log"
    vina --receptor vina_receptor.pdbqt \
      --ligand vina_ligand.pdbqt \
      --config vina_receptor.box.txt \
      --exhaustiveness="$VINA_EXHAUSTIVENESS" \
      --out vina_ligand_vina_out.pdbqt >"$dock_log" 2>&1
    echo "docking log saved: $job_dir/$dock_log"

  # mk_export.py vina_ligand_vina_out.pdbqt -s vina_ligand_vina_out.sdf

  #生成复合物可视化文件
  pymol -cq "$COMPLEX_PML" 

  # PLIP: 需要输入为含受体+配体的复合物 PDB（complex.pdb）
  plip -f "complex.pdb" -o "plip_out" --xml --txt --pics --pymol
  # 可视化
  pymol -cq "$VISUALIZE_PML"

  # cp -f vina_ligand_vina_out.pdbqt "${receptor_id}_${ligand_id}_vina_out.pdbqt"
  # cp -f vina_ligand_vina_out.sdf "${receptor_id}_${ligand_id}_vina_out.sdf"

  popd >/dev/null
}

# 逐行读取：receptor_id receptor_pdb ligand_id smiles
while IFS=$'\t' read -r receptor_id receptor_pdb ligand_id smiles <&3 || [[ -n "${receptor_id:-}${receptor_pdb:-}${ligand_id:-}${smiles:-}" ]]; do
  # 兼容 CRLF（Windows 换行）
  receptor_id=${receptor_id//$'\r'/}
  receptor_pdb=${receptor_pdb//$'\r'/}
  ligand_id=${ligand_id//$'\r'/}
  smiles=${smiles//$'\r'/}

  [[ -z "${receptor_id:-}" ]] && continue
  [[ "$receptor_id" =~ ^# ]] && continue

  # 兼容空格分隔的少量情况
  if [[ -z "${smiles:-}" ]]; then
    read -r receptor_id receptor_pdb ligand_id smiles <<<"$receptor_id"
  fi

  if [[ -z "${receptor_id:-}" || -z "${receptor_pdb:-}" || -z "${ligand_id:-}" || -z "${smiles:-}" ]]; then
    echo "WARNING: invalid line, skip: $receptor_id $receptor_pdb $ligand_id $smiles"
    continue
  fi

  run_one_pair "$receptor_id" "$receptor_pdb" "$ligand_id" "$smiles"
done 3< "$PAIR_FILE"

echo "=== 批量对接完成，结果位于: $OUT_ROOT ==="

conda deactivate
