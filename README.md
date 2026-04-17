## 分子对接
分子对接（Molecular Docking）是一种用于模拟小分子配体（如化合物）与大分子受体（如蛋白质、核酸等）之间相互作用的计算方法。其原理基于分子结构的空间互补性和能量匹配。在生理条件下，配体与受体通过氢键、范德华力、静电作用等非共价相互作用形成稳定的复合物。首先从RCSB PDB 数据库（https://www.rcsb.org/）获取目标蛋白的三维结构文件（.pdb）。随后使用 REDUCE 工具补充缺失的氢原子，并通过PyMOL去除对接中不必要的分子水、配体、辅因子和离子。接着，利用 Fpocket 预测潜在结合口袋，并使用 Meeko生成仅包含极性氢原子和部分电荷的受体PDBQT文件。在配体准备方面，我们从 PubChem 数据库（https://pubchem.ncbi.nlm.nih.gov/）获取小分子的 SMILES 表示，使用Molscrub构建三维构象，枚举可能的互变异构体和质子化状态，再通过Meeko生成包含极性氢、电荷以及可旋转键的配体PDBQT文件。最后，采用AutoDock Vina进行分子对接，借助PLIP分析蛋白质-配体复合物中的非共价相互作用，并通过PyMOL对结果进行三维可视化。
## 使用
pairs.tsv和run_vina_batch.sh放一起，--box 指定对接盒子默认1，运行run_vina_batch.sh
