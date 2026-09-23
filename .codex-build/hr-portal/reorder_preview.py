from __future__ import annotations

import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path


P = "http://schemas.openxmlformats.org/presentationml/2006/main"


def main() -> None:
    source = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    first_slide = int(sys.argv[3])
    with zipfile.ZipFile(source, "r") as zin:
        presentation = ET.fromstring(zin.read("ppt/presentation.xml"))
        slide_list = presentation.find(f"{{{P}}}sldIdLst")
        if slide_list is None:
            raise RuntimeError("presentation has no slide list")
        slides = list(slide_list)
        selected = slides[first_slide - 1]
        slide_list.remove(selected)
        slide_list.insert(0, selected)
        xml = ET.tostring(presentation, encoding="utf-8", xml_declaration=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, output)
    staging = output.parent / "reorder-staging" / "ppt"
    staging.mkdir(parents=True, exist_ok=True)
    (staging / "presentation.xml").write_bytes(xml)
    subprocess.run(
        ["zip", "-q", str(output), "ppt/presentation.xml"],
        cwd=staging.parent,
        check=True,
    )


if __name__ == "__main__":
    main()
