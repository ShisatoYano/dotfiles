#!/usr/bin/env python3
"""ROS 2ワークスペースのinstall/以下からsite-packagesパスを収集し、
pyrightconfig.jsonのextraPathsとして書き出すスクリプト。

使い方:
  python3 generate_pyright_paths.py [ワークスペースパス]
  (省略時はカレントディレクトリを対象にする)
"""
import json
import os
import sys

ws_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
install_dir = os.path.join(ws_dir, "install")

if not os.path.isdir(install_dir):
    sys.exit(f"install ディレクトリが見つかりません: {install_dir}")

paths = []
for root, dirs, files in os.walk(install_dir):
    if root.endswith("site-packages"):
        paths.append(os.path.relpath(root, ws_dir))

paths.sort()

output_path = os.path.join(ws_dir, "pyrightconfig.json")
with open(output_path, "w") as f:
    json.dump({"extraPaths": paths}, f, indent=2)

print(f"{output_path} を生成しました（{len(paths)}件のパス）")
