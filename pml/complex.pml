load vina_receptor.pdbqt, protein
load vina_ligand_vina_out.pdbqt, ligand

# 保存受配体复合物
create complex, protein or ligand
save ../complex.mol2, complex
save complex.pdb, complex
    
# 蛋白基础显示
hide everything
show cartoon, protein
color gray80, protein
show sticks, ligand

# 输出高分辨率截图
ray 2000,1500
png ../cartoon.png, dpi=300

quit