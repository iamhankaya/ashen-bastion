import sys
from pathlib import Path

# tools/art modüllerini (process_art, chroma_key) içe aktarılabilir yap
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
