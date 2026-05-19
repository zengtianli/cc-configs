#!/usr/bin/env python3
"""
ZDWP 自动整理脚本
扫描指定目录，根据文件名关键词和地区自动归类到对应的业务项目目录
"""

import os
import sys
import yaml
import shutil
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple


class ZDWPAutoOrganizer:
    def __init__(self, zdwp_root: str):
        self.zdwp_root = Path(zdwp_root)
        self.temp_dir = self.zdwp_root / "inbox"
        self.skill_dir = self.zdwp_root / ".claude/skills/zdwp-structure"

        # 加载配置
        self.keyword_mapping = self._load_yaml("references/keyword-mapping.yaml")
        self.region_mapping = self._load_yaml("references/region-mapping.yaml")
        self.filetype_rules = self._load_yaml("references/filetype-rules.yaml")

        # 统计
        self.stats = {
            "total": 0,
            "moved": 0,
            "skipped": 0,
            "errors": 0
        }

    def _load_yaml(self, relative_path: str) -> dict:
        """加载 YAML 配置文件"""
        yaml_path = self.skill_dir / relative_path
        if not yaml_path.exists():
            print(f"⚠️  配置文件不存在: {yaml_path}")
            return {}

        with open(yaml_path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)

    def _detect_business(self, filename: str) -> Optional[str]:
        """根据文件名检测业务类型"""
        filename_lower = filename.lower()

        for business, config in self.keyword_mapping.items():
            keywords = config.get('keywords', [])
            for keyword in keywords:
                if keyword in filename_lower:
                    return config['target']

        return None

    def _detect_region(self, filename: str) -> Optional[Tuple[str, str]]:
        """根据文件名检测地区（返回 地市, 县市）"""
        for city, counties in self.region_mapping.items():
            for county in counties:
                if county in filename:
                    return (city, county)

        return None

    def _get_file_category(self, filepath: Path) -> Optional[str]:
        """获取文件类型对应的子目录"""
        ext = filepath.suffix.lower()

        for category, config in self.filetype_rules.items():
            if ext in config.get('extensions', []):
                return config.get('target_subdir')

        return None

    def _build_target_path(self, filepath: Path, business_dir: str,
                          region: Optional[Tuple[str, str]]) -> Optional[Path]:
        """构建目标路径"""
        target_base = self.zdwp_root / business_dir

        # 如果检测到地区，放到县市项目目录
        if region:
            city, county = region
            target_base = target_base / f"{city}-{county}"

        # 获取文件类型对应的子目录
        subdir = self._get_file_category(filepath)

        if subdir is None:
            # 代码文件或未知类型
            if filepath.suffix.lower() in ['.py', '.sh', '.js', '.ts', '.r']:
                print(f"⚠️  代码文件应放到开发部: {filepath.name}")
                return None
            else:
                # 未知类型，放到 data/ 目录
                subdir = "data"

        target_dir = target_base / subdir
        return target_dir / filepath.name

    def _move_file(self, source: Path, target: Path, dry_run: bool = False) -> bool:
        """移动文件"""
        try:
            # 检查目标文件是否已存在
            if target.exists():
                print(f"⚠️  目标文件已存在: {target}")
                # 添加时间戳避免覆盖
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                target = target.parent / f"{target.stem}_{timestamp}{target.suffix}"

            if dry_run:
                print(f"[DRY RUN] {source} -> {target}")
                return True

            # 创建目标目录
            target.parent.mkdir(parents=True, exist_ok=True)

            # 移动文件
            shutil.move(str(source), str(target))
            print(f"✅ {source.name} -> {target.relative_to(self.zdwp_root)}")
            return True

        except Exception as e:
            print(f"❌ 移动失败: {source.name} - {e}")
            return False

    def organize_file(self, filepath: Path, dry_run: bool = False) -> bool:
        """整理单个文件"""
        self.stats["total"] += 1

        # 跳过隐藏文件和系统文件
        if filepath.name.startswith('.') or filepath.name == 'desktop.ini':
            self.stats["skipped"] += 1
            return False

        # 检测业务类型
        business_dir = self._detect_business(filepath.name)
        if not business_dir:
            print(f"⚠️  无法识别业务类型: {filepath.name}")
            self.stats["skipped"] += 1
            return False

        # 检测地区
        region = self._detect_region(filepath.name)

        # 构建目标路径
        target_path = self._build_target_path(filepath, business_dir, region)
        if not target_path:
            self.stats["skipped"] += 1
            return False

        # 移动文件
        if self._move_file(filepath, target_path, dry_run):
            self.stats["moved"] += 1
            return True
        else:
            self.stats["errors"] += 1
            return False

    def scan_and_organize(self, dry_run: bool = False):
        """扫描临时目录并整理"""
        if not self.temp_dir.exists():
            print(f"❌ 临时目录不存在: {self.temp_dir}")
            return

        print(f"📂 扫描目录: {self.temp_dir}")
        print(f"{'=' * 60}")

        # 递归扫描所有文件
        files = []
        for root, dirs, filenames in os.walk(self.temp_dir):
            # 跳过隐藏目录
            dirs[:] = [d for d in dirs if not d.startswith('.')]

            for filename in filenames:
                filepath = Path(root) / filename
                if filepath.is_file():
                    files.append(filepath)

        if not files:
            print("📭 临时目录为空")
            return

        print(f"📊 找到 {len(files)} 个文件\n")

        # 整理每个文件
        for filepath in files:
            self.organize_file(filepath, dry_run)

        # 打印统计
        print(f"\n{'=' * 60}")
        print(f"📊 整理完成:")
        print(f"   总文件数: {self.stats['total']}")
        print(f"   已移动: {self.stats['moved']}")
        print(f"   跳过: {self.stats['skipped']}")
        print(f"   错误: {self.stats['errors']}")


def main():
    import argparse

    parser = argparse.ArgumentParser(description='ZDWP 自动整理脚本')
    parser.add_argument('--zdwp-root', default='/Users/tianli/Dev/Work/projects/zdwp',
                       help='ZDWP 根目录路径')
    parser.add_argument('--dry-run', action='store_true',
                       help='试运行模式，不实际移动文件')

    args = parser.parse_args()

    organizer = ZDWPAutoOrganizer(args.zdwp_root)
    organizer.scan_and_organize(dry_run=args.dry_run)


if __name__ == '__main__':
    main()
