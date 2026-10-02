#!/usr/bin/env python3
"""Build all DocC archives and verify declared API coverage and guide examples."""

import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".build" / "documentation"
PRODUCTS = OUTPUT / "Build" / "Products" / "Debug-iphonesimulator"
MODULES = ("TestCommons", "TestCommonsXCUI", "TestCommonsUI")


def build():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    log = OUTPUT / "build.log"
    command = [
        "xcodebuild",
        "-scheme", "TestCommonsXCUI",
        "-destination", "generic/platform=iOS Simulator",
        "-derivedDataPath", str(OUTPUT),
        "docbuild",
        "OTHER_DOCC_FLAGS=--warnings-as-errors --analyze "
        "--experimental-documentation-coverage",
    ]
    print("Building DocC archives for all products…", flush=True)
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        if result.returncode == 0:
            command[2] = "TestCommonsUI"
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        print(log.read_text())
        raise SystemExit(result.returncode)
    print(f"Build log: {log}")


def check_coverage(module):
    symbols = {}
    graphs = OUTPUT / "Build" / "Intermediates.noindex"
    for path in graphs.rglob("*.symbols.json"):
        graph = json.loads(path.read_text())
        if graph["module"]["name"] != module:
            continue
        for symbol in graph["symbols"]:
            # Inherited protocol implementations and synthesized operators are not
            # declarations owned by this package. Extension containers are represented
            # by DocC's extended-type pages rather than their compiler identifiers.
            if not symbol.get("location") or symbol["kind"]["identifier"] == "swift.extension":
                continue
            if symbol["accessLevel"] in ("public", "open"):
                symbols[symbol["identifier"]["precise"]] = symbol
    if not symbols:
        raise SystemExit(f"No declared public symbols found for {module}")

    archive = PRODUCTS / f"{module}.doccarchive"
    coverage = {
        entry["referencePath"]: entry
        for entry in json.loads((archive / "documentation-coverage.json").read_text())
    }
    pages = {}
    for path in (archive / "data" / "documentation").rglob("*.json"):
        page = json.loads(path.read_text())
        identifier = page.get("metadata", {}).get("externalID")
        if identifier:
            pages[identifier] = page

    errors = []
    for identifier, symbol in symbols.items():
        name = "/".join(symbol["pathComponents"])
        page = pages.get(identifier)
        if not symbol.get("docComment", {}).get("lines"):
            errors.append(f"{name}: missing source documentation")
        if not page:
            errors.append(f"{name}: missing rendered DocC page")
            continue
        entry = coverage[page["identifier"]["url"]]
        if not entry["hasAbstract"] or not entry["isCurated"]:
            errors.append(f"{name}: missing summary or Topics curation")
        signature = symbol.get("functionSignature", {})
        expected_parameters = {
            parameter.get("internalName", parameter["name"])
            for parameter in signature.get("parameters", [])
        }
        documented_parameters = {
            parameter["name"]
            for section in page.get("primaryContentSections", [])
            if section["kind"] == "parameters"
            for parameter in section["parameters"]
        }
        if expected_parameters - documented_parameters:
            errors.append(f"{name}: incomplete parameter documentation")
        returns = "".join(fragment["spelling"] for fragment in signature.get("returns", []))
        kind = symbol["kind"]["identifier"]
        if kind in ("swift.func", "swift.method", "swift.type.method") and returns not in ("", "Void", "()"):
            if not any(
                content.get("anchor") == "return-value"
                for section in page.get("primaryContentSections", [])
                for content in section.get("content", [])
            ):
                errors.append(f"{name}: missing return-value documentation")
    if errors:
        raise SystemExit(f"{module} documentation gaps:\n" + "\n".join(errors))
    print(f"{module}: {len(symbols)}/{len(symbols)} declared public APIs documented and curated")
    print(f"Archive: {archive}")


def check_examples():
    sdk = Path(subprocess.check_output(
        ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True
    ).strip())
    examples = OUTPUT / "examples"
    examples.mkdir(exist_ok=True)
    count = 0
    for module in MODULES:
        catalog = ROOT / "Sources" / module / f"{module}.docc"
        for article in sorted(catalog.glob("*.md")):
            for number, code in enumerate(re.findall(r"```swift\n(.*?)\n```", article.read_text(), re.DOTALL), 1):
                source = examples / f"{article.stem}-{number}.swift"
                source.write_text(code + "\n")
                subprocess.run([
                    "xcrun", "swiftc", "-typecheck", "-swift-version", "6",
                    "-target", "arm64-apple-ios18.0-simulator", "-sdk", str(sdk),
                    "-I", str(PRODUCTS),
                    "-I", str(sdk.parents[1] / "usr" / "lib"),
                    "-F", str(sdk.parents[1] / "Library" / "Frameworks"),
                    str(source),
                ], cwd=ROOT, check=True)
                count += 1
    if not count:
        raise SystemExit("No Swift guide examples found")
    print(f"Type-checked {count} Swift guide examples")


if __name__ == "__main__":
    build()
    for module in MODULES:
        check_coverage(module)
    check_examples()
