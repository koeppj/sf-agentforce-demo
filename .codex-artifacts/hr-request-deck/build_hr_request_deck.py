from copy import deepcopy
from pathlib import Path
import posixpath
import re
from zipfile import ZIP_DEFLATED, BadZipFile, ZipFile

from lxml import etree as ET


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "template-review" / "box-template-source.pptx"
CANDIDATE = ROOT / "build" / "hr-request-portal-business-overview-candidate.pptx"

P_NS = "http://schemas.openxmlformats.org/presentationml/2006/main"
A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
EP_NS = "http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
VT_NS = "http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"

NS = {"p": P_NS, "a": A_NS, "r": R_NS, "pr": REL_NS, "ep": EP_NS, "vt": VT_NS}


def qn(namespace, tag):
    return f"{{{namespace}}}{tag}"


def shape_by_name(root, name):
    matches = root.xpath(f'.//p:sp[p:nvSpPr/p:cNvPr[@name="{name}"]]', namespaces=NS)
    if len(matches) != 1:
        raise ValueError(f"Expected one shape named {name!r}, found {len(matches)}")
    return matches[0]


def _first_run_properties(paragraph):
    rpr = paragraph.find("./a:r/a:rPr", NS)
    if rpr is not None:
        return deepcopy(rpr)
    def_rpr = paragraph.find("./a:pPr/a:defRPr", NS)
    if def_rpr is not None:
        return deepcopy(def_rpr)
    return ET.Element(qn(A_NS, "rPr"), lang="en-US")


def _prepare_run_properties(rpr, size_pt, bold=None, color=None):
    rpr.set("lang", "en-US")
    rpr.set("sz", str(int(size_pt * 100)))
    if bold is not None:
        rpr.set("b", "1" if bold else "0")
    for child_name in ("latin", "ea", "cs"):
        child = rpr.find(f"./a:{child_name}", NS)
        if child is None:
            child = ET.SubElement(rpr, qn(A_NS, child_name))
        child.set("typeface", "Inter" if child_name == "latin" else "+mn-ea")
    if color:
        solid = rpr.find("./a:solidFill", NS)
        if solid is None:
            solid = ET.Element(qn(A_NS, "solidFill"))
            rpr.insert(0, solid)
        for child in list(solid):
            solid.remove(child)
        ET.SubElement(solid, qn(A_NS, "srgbClr"), val=color)
    return rpr


def _replace_paragraph_text(paragraph, text, size_pt, bold=None, color=None):
    rpr = _prepare_run_properties(_first_run_properties(paragraph), size_pt, bold, color)
    for child in list(paragraph):
        if child.tag in {qn(A_NS, "r"), qn(A_NS, "br"), qn(A_NS, "fld")}:
            paragraph.remove(child)
    run = ET.Element(qn(A_NS, "r"))
    run.append(rpr)
    node = ET.SubElement(run, qn(A_NS, "t"))
    node.text = text
    end = paragraph.find("./a:endParaRPr", NS)
    paragraph.insert(paragraph.index(end) if end is not None else len(paragraph), run)


def set_single_text(shape, text, size_pt, bold=None, color=None):
    tx = shape.find("./p:txBody", NS)
    if tx is None:
        raise ValueError("Shape has no text body")
    paragraphs = tx.findall("./a:p", NS)
    if not paragraphs:
        paragraphs = [ET.SubElement(tx, qn(A_NS, "p"))]
    _replace_paragraph_text(paragraphs[0], text, size_pt, bold, color)
    for paragraph in paragraphs[1:]:
        tx.remove(paragraph)


def set_card_text(shape, header, body_lines, header_size=20, body_size=15):
    tx = shape.find("./p:txBody", NS)
    paragraphs = tx.findall("./a:p", NS)
    if not paragraphs:
        raise ValueError("Card shape has no paragraphs")
    header_template = deepcopy(paragraphs[0])
    body_template = deepcopy(paragraphs[1] if len(paragraphs) > 1 else paragraphs[0])
    for paragraph in paragraphs:
        tx.remove(paragraph)

    header_p = deepcopy(header_template)
    _replace_paragraph_text(header_p, header, header_size, True, "FFFFFF")
    tx.append(header_p)

    for line in body_lines:
        body_p = deepcopy(body_template)
        ppr = body_p.find("./a:pPr", NS)
        if ppr is None:
            ppr = ET.Element(qn(A_NS, "pPr"))
            body_p.insert(0, ppr)
        ppr.set("marL", "0")
        ppr.set("indent", "0")
        for bullet in ppr.xpath("./a:buChar|./a:buAutoNum|./a:buNone", namespaces=NS):
            ppr.remove(bullet)
        _replace_paragraph_text(body_p, line, body_size, False, "FFFFFF")
        tx.append(body_p)


def edit_solution_slide(data):
    root = ET.fromstring(data)
    set_single_text(shape_by_name(root, "Google Shape;442;p32"), "HR Request Portal solution approach", 30, True, "000000")
    set_single_text(
        shape_by_name(root, "Google Shape;443;p32"),
        "A single employee journey connects intake, case management, and secure Box content",
        18,
        False,
        "4E4E4E",
    )
    set_single_text(shape_by_name(root, "Google Shape;444;p32"), "", 10, False, "767676")
    steps = {
        "Google Shape;446;p32": "Submit HR request",
        "Google Shape;447;p32": "Create Portal Request Case",
        "Google Shape;449;p32": "Provision Box folder",
        "Google Shape;448;p32": "Grant access and upload",
        "Google Shape;450;p32": "Track and resolve",
    }
    for name, text in steps.items():
        set_single_text(shape_by_name(root, name), text, 18, True, "FFFFFF")
    return ET.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")


def edit_options_slide(data):
    root = ET.fromstring(data)
    set_single_text(shape_by_name(root, "Google Shape;256;p18"), "HR intake implementation options", 30, True, "000000")
    set_single_text(
        shape_by_name(root, "Google Shape;257;p18"),
        "Choose based on form complexity, catalog size, and expected change frequency",
        18,
        False,
        "4E4E4E",
    )
    set_card_text(
        shape_by_name(root, "Google Shape;261;p18"),
        "v1  Admin-built Flow",
        [
            "One Flow per form and version",
            "Builds on the current New Hire path",
            "Best for a small, stable catalog",
        ],
        body_size=14,
    )
    set_card_text(
        shape_by_name(root, "Google Shape;265;p18"),
        "v2  Schema-driven form",
        [
            "One shared Flow and form component",
            "New forms publish through Box JSON",
            "Best for many standardized forms",
        ],
        body_size=14,
    )
    set_card_text(
        shape_by_name(root, "Google Shape;266;p18"),
        "v3  Guided Flow",
        [
            "One multi-screen Flow per request type",
            "Supports branching and skipped screens",
            "Best for complex employee journeys",
        ],
        body_size=14,
    )
    return ET.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")


def edit_components_slide(data):
    root = ET.fromstring(data)
    set_single_text(shape_by_name(root, "Google Shape;238;p17"), "Components required", 30, True, "000000")
    set_single_text(
        shape_by_name(root, "Google Shape;239;p17"),
        "A shared portal backbone supports every intake model",
        18,
        False,
        "4E4E4E",
    )
    cards = [
        (
            "Google Shape;242;p17",
            "Employee portal",
            ["Authenticated page and navigation", "Access for every eligible profile", "Internal and external users"],
        ),
        (
            "Google Shape;245;p17",
            "Case orchestration",
            ["Portal Request record type", "New, Working, and Closed status", "Ownership, sharing, automation guard"],
        ),
        (
            "Google Shape;248;p17",
            "Box content",
            ["Case folder and Editor access", "Direct multi-file upload", "Identity and site trust setup"],
        ),
        (
            "Google Shape;251;p17",
            "HR form services",
            ["Selected v1, v2, or v3 model", "Box JSON and Doc Gen as needed", "Shared status and receipt pattern"],
        ),
    ]
    for name, header, body in cards:
        set_card_text(shape_by_name(root, name), header, body, header_size=19, body_size=14)
    return ET.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")


def edit_presentation(data, rels_data):
    root = ET.fromstring(data)
    rels = ET.fromstring(rels_data)
    target_to_rid = {
        rel.get("Target"): rel.get("Id")
        for rel in rels.findall(f"./{{{REL_NS}}}Relationship")
        if rel.get("Type", "").endswith("/slide")
    }
    desired = ["slides/slide32.xml", "slides/slide18.xml", "slides/slide17.xml"]
    rid_order = [target_to_rid[item] for item in desired]
    slide_list = root.find("./p:sldIdLst", NS)
    by_rid = {item.get(qn(R_NS, "id")): deepcopy(item) for item in slide_list}
    for child in list(slide_list):
        slide_list.remove(child)
    for rid in rid_order:
        slide_list.append(by_rid[rid])
    for tag in ("custShowLst", "sectionLst"):
        for node in root.findall(f"./p:{tag}", NS):
            root.remove(node)
    return ET.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")


def edit_presentation_relationships(data):
    root = ET.fromstring(data)
    keep = {"slides/slide32.xml", "slides/slide18.xml", "slides/slide17.xml"}
    for rel in list(root):
        if rel.get("Type", "").endswith("/slide") and rel.get("Target") not in keep:
            root.remove(rel)
    return ET.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")


def edit_content_types(data):
    root = ET.fromstring(data)
    keep_slides = {"/ppt/slides/slide32.xml", "/ppt/slides/slide18.xml", "/ppt/slides/slide17.xml"}
    for override in list(root):
        part = override.get("PartName", "")
        if part.startswith("/ppt/slides/slide") and part not in keep_slides:
            root.remove(override)
        elif part.startswith("/ppt/notesSlides/"):
            root.remove(override)
    return ET.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")


def strip_slide_sidecars(data):
    root = ET.fromstring(data)
    for rel in list(root):
        if rel.get("Type", "").endswith(("/notesSlide", "/comments")):
            root.remove(rel)
    return ET.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")


def edit_app_properties(data):
    root = ET.fromstring(data)
    slides = root.find("./ep:Slides", NS)
    if slides is not None:
        slides.text = "3"
    hidden = root.find("./ep:HiddenSlides", NS)
    if hidden is not None:
        hidden.text = "0"
    return ET.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")


def _rels_path_for_part(part):
    if part == "":
        return "_rels/.rels"
    directory, name = posixpath.split(part)
    return posixpath.join(directory, "_rels", f"{name}.rels")


def _relationship_target(source_part, target):
    if target.startswith("/"):
        return target.lstrip("/")
    return posixpath.normpath(posixpath.join(posixpath.dirname(source_part), target))


def prune_package(package_path):
    pruned_path = package_path.with_name(f"{package_path.stem}-pruned.pptx")
    with ZipFile(package_path, "r") as zin:
        names = {item.filename for item in zin.infolist() if not item.is_dir()}
        reachable = {"[Content_Types].xml", "_rels/.rels"}
        queue = [""]
        visited = set()
        while queue:
            source_part = queue.pop()
            if source_part in visited:
                continue
            visited.add(source_part)
            rels_path = _rels_path_for_part(source_part)
            if rels_path not in names:
                continue
            reachable.add(rels_path)
            rels_root = ET.fromstring(zin.read(rels_path))
            for rel in rels_root.findall(f"./{{{REL_NS}}}Relationship"):
                if rel.get("TargetMode") == "External":
                    continue
                target = _relationship_target(source_part, rel.get("Target", ""))
                if target in names:
                    if target not in reachable:
                        reachable.add(target)
                        queue.append(target)

        content_types = ET.fromstring(zin.read("[Content_Types].xml"))
        for override in list(content_types):
            part = override.get("PartName", "").lstrip("/")
            if part and part not in reachable:
                content_types.remove(override)
        content_types_data = ET.tostring(
            content_types, xml_declaration=True, encoding="UTF-8", standalone="yes"
        )

        with ZipFile(pruned_path, "w", compression=ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                if item.is_dir() or item.filename not in reachable:
                    continue
                data = content_types_data if item.filename == "[Content_Types].xml" else zin.read(item.filename)
                zout.writestr(item, data)
    pruned_path.replace(package_path)


def main():
    CANDIDATE.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(SOURCE, "r") as zin, ZipFile(CANDIDATE, "w", compression=ZIP_DEFLATED) as zout:
        presentation_rels = zin.read("ppt/_rels/presentation.xml.rels")
        for item in zin.infolist():
            slide_match = re.fullmatch(r"ppt/slides/slide(\d+)\.xml", item.filename)
            slide_rels_match = re.fullmatch(r"ppt/slides/_rels/slide(\d+)\.xml\.rels", item.filename)
            if slide_match and int(slide_match.group(1)) not in {17, 18, 32}:
                continue
            if slide_rels_match and int(slide_rels_match.group(1)) not in {17, 18, 32}:
                continue
            if item.filename.startswith("ppt/notesSlides/"):
                continue
            try:
                data = zin.read(item.filename)
            except BadZipFile:
                print(f"Skipping corrupt, unused template part: {item.filename}")
                continue
            if item.filename == "ppt/presentation.xml":
                data = edit_presentation(data, presentation_rels)
            elif item.filename == "ppt/_rels/presentation.xml.rels":
                data = edit_presentation_relationships(data)
            elif item.filename == "ppt/slides/slide32.xml":
                data = edit_solution_slide(data)
            elif item.filename == "ppt/slides/slide18.xml":
                data = edit_options_slide(data)
            elif item.filename == "ppt/slides/slide17.xml":
                data = edit_components_slide(data)
            elif item.filename in {
                "ppt/slides/_rels/slide32.xml.rels",
                "ppt/slides/_rels/slide18.xml.rels",
                "ppt/slides/_rels/slide17.xml.rels",
            }:
                data = strip_slide_sidecars(data)
            elif item.filename == "docProps/app.xml":
                data = edit_app_properties(data)
            elif item.filename == "[Content_Types].xml":
                data = edit_content_types(data)
            zout.writestr(item, data)
    prune_package(CANDIDATE)
    print(CANDIDATE)


if __name__ == "__main__":
    main()
