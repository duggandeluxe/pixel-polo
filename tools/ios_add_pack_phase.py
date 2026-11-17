#!/usr/bin/env python3
"""Adds the "Pack Godot project" build phase to the Xcode project that Godot's iOS export writes.

Godot rewrites project.pbxproj on every full export, so tools/build_ios.sh runs this after each one.
The phase runs tools/ios_pack_for_xcode.sh before resources are copied, so a Run always packs the
current game. It also turns off user script sandboxing, which would stop that script writing into
the project. Running this on a project that already has the phase changes nothing.
"""
import re
import sys
from pathlib import Path

PHASE_ID = "5E0C0DE0A1B2C3D4E5F60001"
PHASE_NAME = "Pack Godot project"
def _bundle_id() -> str:
    """The iOS preset's bundle identifier (game/export_presets.cfg): set it there, nowhere else."""
    cfg = Path(__file__).resolve().parent.parent / "game" / "export_presets.cfg"
    text = cfg.read_text(encoding="utf-8")
    for section in re.split(r"^\[preset\.\d+\]$", text, flags=re.M):
        if 'platform="iOS"' in section:
            m = re.search(r'^application/bundle_identifier="([^"]*)"', section, flags=re.M)
            if m:
                return m.group(1)
    sys.exit("error: no iOS bundle identifier in game/export_presets.cfg")


BUNDLE_LINE = f"PRODUCT_BUNDLE_IDENTIFIER = {_bundle_id()};"

PHASE_BLOCK = (
    f"\t\t{PHASE_ID} /* {PHASE_NAME} */ = {{\n"
    "\t\t\tisa = PBXShellScriptBuildPhase;\n"
    "\t\t\talwaysOutOfDate = 1;\n"
    "\t\t\tbuildActionMask = 2147483647;\n"
    "\t\t\tfiles = (\n\t\t\t);\n"
    "\t\t\tinputFileListPaths = (\n\t\t\t);\n"
    "\t\t\tinputPaths = (\n\t\t\t);\n"
    f'\t\t\tname = "{PHASE_NAME}";\n'
    "\t\t\toutputFileListPaths = (\n\t\t\t);\n"
    "\t\t\toutputPaths = (\n\t\t\t);\n"
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    "\t\t\tshellPath = /bin/sh;\n"
    '\t\t\tshellScript = "\\"$SRCROOT/../../tools/ios_pack_for_xcode.sh\\"\\n";\n'
    "\t\t\tshowEnvVarsInLog = 0;\n"
    "\t\t};\n"
)


def add_phase_section(text: str) -> str:
    section = (
        "/* Begin PBXShellScriptBuildPhase section */\n"
        + PHASE_BLOCK
        + "/* End PBXShellScriptBuildPhase section */\n"
    )
    anchor = "/* Begin PBXSourcesBuildPhase section */\n"
    if text.count(anchor) != 1:
        raise SystemExit("unexpected project.pbxproj layout: no single PBXSourcesBuildPhase section")
    return text.replace(anchor, section + anchor, 1)


def add_to_target(text: str) -> str:
    match = re.search(
        r"/\* Begin PBXNativeTarget section \*/.*?/\* End PBXNativeTarget section \*/", text, re.S
    )
    if match is None:
        raise SystemExit("unexpected project.pbxproj layout: no PBXNativeTarget section")
    target = match.group(0)
    # Put the phase just before Resources, so the pack finishes before the .pck is copied in.
    new_target, count = re.subn(
        r"^(\t+)(\w+ /\* Resources \*/,)$",
        lambda m: f"{m.group(1)}{PHASE_ID} /* {PHASE_NAME} */,\n{m.group(1)}{m.group(2)}",
        target,
        flags=re.M,
    )
    if count != 1:
        raise SystemExit("unexpected project.pbxproj layout: no Resources phase on the target")
    return text.replace(target, new_target, 1)


def disable_sandboxing(text: str) -> str:
    pattern = re.compile(r"(\t\t\tbuildSettings = \{\n)(.*?)(\n\t\t\t\};)", re.S)

    def fix(m: re.Match) -> str:
        head, body, tail = m.groups()
        if BUNDLE_LINE not in body or "ENABLE_USER_SCRIPT_SANDBOXING" in body:
            return m.group(0)
        return f"{head}\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = NO;\n{body}{tail}"

    return pattern.sub(fix, text)


def main() -> None:
    path = Path(sys.argv[1])
    text = path.read_text()
    if PHASE_ID in text:
        print(f"{PHASE_NAME} phase already in {path}")
        return
    text = disable_sandboxing(add_to_target(add_phase_section(text)))
    path.write_text(text)
    print(f"Added the {PHASE_NAME} phase to {path}")


if __name__ == "__main__":
    main()
