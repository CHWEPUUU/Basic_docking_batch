python
import os

pocket_file = os.environ.get("POCKET_FILE", "./receptor_clean_out/pockets/pocket1_atm.pdb")
pocket_obj = os.environ.get("POCKET_OBJ", "p1")

cmd.load(pocket_file, pocket_obj)
minmax = cmd.get_extent(pocket_obj)
center_x = (minmax[0][0] + minmax[1][0]) / 2.0
center_y = (minmax[0][1] + minmax[1][1]) / 2.0
center_z = (minmax[0][2] + minmax[1][2]) / 2.0

size_x = minmax[1][0] - minmax[0][0] + 6.0
size_y = minmax[1][1] - minmax[0][1] + 6.0
size_z = minmax[1][2] - minmax[0][2] + 6.0

with open("box_center.txt","w") as f:
    f.write(f"{center_x:.1f} {center_y:.1f} {center_z:.1f}\n")

with open("box_size.txt","w") as f:
    f.write(f"{size_x:.1f} {size_y:.1f} {size_z:.1f}\n")

print("Pocket file:", pocket_file)
print("Pocket object:", pocket_obj)
print("Box center (extent midpoint):", center_x, center_y, center_z)
print("Box size (with buffer):", size_x, size_y, size_z)
python end

quit
