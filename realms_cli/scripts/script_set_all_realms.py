import subprocess

batch_size = 50

for i in range(1,8000, batch_size):
    subprocess.run(f"nile set_realm_data {i}-{i+batch_size-1}", shell=True, check=True)