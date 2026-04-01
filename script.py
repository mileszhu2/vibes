import csv

with open('pause_quit_chosen.csv', 'r') as file:
    reader = csv.reader(file)
    flattened_list = [item for sublist in list(reader) for item in sublist]

code = ""

for i in range(len(flattened_list)):
    if flattened_list[i] == '1':
        code += f"sw $t1, {4*i}($t0)\n"

print(code)
